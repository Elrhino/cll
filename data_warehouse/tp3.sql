-- =============================================
-- Author:		Renaud Lain�
-- Create date: 2015-02-27
-- Description:	TP3
-- =============================================

use tp2_entrepot;
go

-- Drop Procedures
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_maj_fv')
   DROP PROCEDURE proc_maj_fv
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_maj_clients')
   DROP PROCEDURE proc_maj_clients
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_maj_produits')
   DROP PROCEDURE proc_maj_produits
GO

create procedure proc_maj_fv
as
	begin
		declare
		@dateDerniereVenteFV as date,  -- Date de la derni�re vente dans Fait Vente.
		@dateDerniereVenteNW as date,  -- Date de la derni�re vente dans Northwind.
		@curseurVentes as cursor,
		@unitPrice as money,
		@quantity as int, 
		@orderId as int,
		@customerId as nchar(5),
		@employeeId as int,
		@productId as int,
		@idDC as int,        -- ID dimension client.
		@idDP as int,        -- ID dimension produit.
		@idDE as int,        -- ID dimension employ�.
		@idDT as int,        -- ID dimension temps (date).
		@employeeName as nvarchar(30),
		@employeeTitle as nvarchar(30),
		@orderDate as datetime;
		
		set @dateDerniereVenteFV = (
			select top 1 date_vente 
			from tp2_entrepot.dbo.fait_vente fv 
				inner join date_details dt on fv.id_date = dt.id_date
			order by date_vente desc
		);
									 
		set @dateDerniereVenteNW = (
			select top 1 orderDate 
			from northwind.dbo.orders 
			order by orderDate desc
		);
								  
		if @dateDerniereVenteNW > @dateDerniereVenteFV
		begin
			set @curseurVentes = cursor for
			select
				p.unitPrice, 
				od.quantity,
				o.orderID,
				c.customerID,
				p.productID,
				e.FirstName + ' ' + e.LastName as 'Nom de l''employ�',
				e.Title,
				o.orderDate
			from northwind.dbo.orders as o
				inner join northwind.dbo.[Order Details] as od on o.orderId = od.orderId
				inner join northwind.dbo.customers as c on o.customerId = c.customerId
				inner join northwind.dbo.employees as e on o.employeeId = e.employeeId
				inner join northwind.dbo.products as p on od.productId = p.productId
			where orderDate > @dateDerniereVenteFV
			order by orderDate;
		end
		else
		begin
			print('* Rien � mettre � jour');	
			return;
		end -- END ELSE
		
		open @curseurVentes;
		fetch @curseurVentes into @unitPrice, @quantity, @orderId, @customerId, @productId, @employeeName, @employeeTitle, @orderDate;
		
		while @@fetch_status = 0
		begin
			set @idDC = (select max(id_client) from dbo.dimension_client where identificateur=@customerId);
			set @idDP = (select max(id_produit) from dbo.dimension_produit where identifiant=@productId);
			set @idDE = (select id_employe from dbo.dimension_employe where nom_employe = @employeeName and titre = @employeeTitle);
			set @idDT = (select id_date from tp2_entrepot.dbo.date_details where date_vente = @orderDate);
			
			insert into dbo.fait_vente values (@unitPrice, @quantity, @idDC, @idDP, @idDE, @idDT);
			
			fetch @curseurVentes into @unitPrice, @quantity, @orderId, @customerId, @productId, @employeeName, @employeeTitle, @orderDate;
		end -- END WHILE
		
		close @curseurVentes;
	end
go


create procedure proc_maj_clients
as
	begin
		declare
		@curseurClientsNW as cursor,    -- Curseur des clients dans Northwind.
		@idClientDC as int,             -- ID du client dans la dimension client.
		@idAncientClient as int,
		@nomContact as nvarchar(30),
		@nomVille as nvarchar(15),
		@villeCompare as nvarchar(15),
		@nomPays as nvarchar(15),
		@customerID as nchar(5),
		@nbOccurences as int,
		@continent as nvarchar(100),
		@TSQL as nvarchar(4000);
		
		set @curseurClientsNW = cursor for
			select contactName, city, country, customerId
			from northwind.dbo.customers;
			
		open @curseurClientsNW;
		fetch @curseurClientsNW into @nomContact, @nomVille, @nomPays, @customerID;
		
		while @@fetch_status = 0
		begin
			SELECT @TSQL = N'SELECT @ContinentOut = continent FROM OPENQUERY(ORACLE,''SELECT continent FROM system.corrpayscont WHERE lower(country) = lower(''''' + @nomPays + ''''')'')'
			exec sp_executesql 
			@TSQL, 
			N'@ContinentOut nvarchar(100) OUT', 
			@ContinentOut=@continent OUT

			set @nbOccurences = (
				select count(*) from dbo.dimension_client
				where identificateur = @customerID
			);
			
			-- Si le client n'existe pas dans la dimension, on l'ajoute.
			if @nbOccurences = 0
			begin
				print('* Nouveau client ajout� � la dimension.');
				insert into dbo.dimension_client (nom_contact, nom_ville, nom_pays, continent, identificateur)
					values (@nomContact, @nomVille, @nomPays, @continent, @customerID);
			end
			else
			begin
				-- R�cup�re la derni�re ville associ� au client.
				set @villeCompare = (
					select nom_ville from dbo.dimension_client 
					where id_client = (
						select max(id_client) from dbo.dimension_client 
						where identificateur=@customerID
					)
				);
				
				-- Compare la derni�re ville avec celle de Northwind.
				if @nomVille != @villeCompare
				begin
					print('* Mise � jour ville client: ' + @customerID);
					print(@nomVille);
					print(@villeCompare);
					set @idClientDC = (select max(id_client) from dbo.dimension_client where identificateur = @customerID);
					
					insert into dbo.dimension_client (nom_contact, nom_ville, nom_pays, continent, id_ancient_client, identificateur)
						values (@nomContact, @nomVille, @nomPays, @continent, @idClientDC, @customerID);
				end
			end -- END ELSE
					
			fetch @curseurClientsNW into @nomContact, @nomVille, @nomPays, @customerID;
		end -- END WHILE
		
		close @curseurClientsNW;
	end
go


create procedure proc_maj_produits
as
	begin
		declare
		@curseurProduits as cursor,
		@nomProduit as nvarchar(40),
		@nomFournisseur as nvarchar(40),
		@dernierFournisseur as nvarchar(40),
		@categorie as nvarchar(15),
		@pays as nvarchar(15),
		@systemeMesure as nvarchar(20),
		@productID as int,               -- ID du produit dans Northwind.
		@idDP as int,                    -- ID du produit dans la dimension.
		@nbOccurences as int,
		@nbFournisseurs as smallint;
		
		set @curseurProduits = cursor for
			select p.productName, s.companyName, c.categoryName, s.country, p.quantityPerUnit, p.productID
			from northwind.dbo.products as p
				inner join northwind.dbo.suppliers as s on p.supplierId = s.supplierId
				inner join northwind.dbo.categories as c on p.categoryId = c.categoryId;
		
		open @curseurProduits;
		fetch @curseurProduits into @nomProduit, @nomFournisseur, @categorie, @pays, @systemeMesure, @productID;
			
		while @@fetch_status = 0
		begin
		
			-- V�rifie si le produit existe dans la dimension.	
			set @nbOccurences = (
				select count(*) from dbo.dimension_produit
				where identifiant = @productID
			);
			
			if @nbOccurences = 0
			begin
				print('* Nouveau produit ajout� � la dimension.');
				insert into dbo.dimension_produit (nom_produit, nom_fournisseur, categorie, pays_fournisseur, systeme_mesure, identifiant)
					values (@nomProduit, @nomFournisseur, @categorie, @pays, @systemeMesure, @productID);
			end
			else
			begin				
				-- R�cup�re le derni�re fournisseur associ� au produit.
				set @dernierFournisseur = (
				select nom_fournisseur from dbo.dimension_produit 
				where id_produit = (
					select max(id_produit) from dbo.dimension_produit
					where identifiant=@productID
					)
				);
				
				-- Compare le dernier fournisseur associ� au produit au celui de NorthWind.
				if @dernierFournisseur != @nomFournisseur
				begin
					-- V�rifie que le fournisseur n'est pas chang� plus de 3 fois.
					set @nbFournisseurs = (select count(*) from dbo.dimension_produit where identifiant=@productID);

					if @nbFournisseurs < 4
					begin
						print('* Mise � jour du fournisseur pour le produit: ' + @nomProduit);
						set @idDP = (select max(id_produit) from dbo.dimension_produit where identifiant=@productID);
						insert into dbo.dimension_produit
							values (@nomProduit, @nomFournisseur, @categorie, @pays, @systemeMesure, @productID, @idDP);
					end
				end
			end -- END IF
			
			fetch @curseurProduits into @nomProduit, @nomFournisseur, @categorie, @pays, @systemeMesure, @productID;
		end -- END WHILE
		
		close @curseurProduits;
	end
go

exec proc_maj_clients
exec proc_maj_produits
exec proc_maj_fv
