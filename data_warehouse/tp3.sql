-- =============================================
-- Author:		Renaud Lainé
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

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'FN' AND name = 'func_recupere_continent')
   DROP FUNCTION func_recupere_continent
GO

create procedure proc_maj_fv
as
	begin
		declare
		@dateDerniereVenteFV as date,  -- Date de la dernière vente dans Fait Vente.
		@dateDerniereVenteNW as date,  -- Date de la dernière vente dans Northwind.
		@curseurVentes as cursor,
		@unitPrice as money,
		@quantity as int, 
		@orderId as int,
		@customerId as int,
		@employeeId as int,
		@productId as int;
		
		set @dateDerniereVenteFV = (
			select top 1 date_vente 
			from tp2_entrepot.dbo.date_details 
			order by date_vente desc
		);
									 
		set @dateDerniereVenteNW = (
			select top 1 orderDate 
			from northwind.dbo.orders 
			order by orderDate desc
		);
								  
		if @dateDerniereVenteNW > @dateDerniereVenteFV
			set @curseurVentes = cursor for
			select o.unitPrice, o.quantity, o.orderId, o.customerId, o.employeeId, od.productId
			from northwind.dbo.orders as o
				inner join northwind.dbo.[Orders Details] as od on o.orderId = od.orderId
				inner join northwind.dbo.customers as c on o.customerId = c.customerId
				inner join northwind.dbo.employes as e on o.employeeId = e.employeeId
				inner join northwind.dbo.products as p on od.productId = p.productId
			where orderDate > @dateDerniereVenteFV
			order by orderDate;
		else
		begin
			print('* Rien à mettre à jour');	
			return;
		end -- END ELSE
		
		open @curseurVentes;
		fetch @curseurVentes into @unitPrice, @quantity, @orderId, @customerId, @employeeId, @productId;
	
		-- TODO: Executer les autres procédures ici <-----
		
	end
go

create function func_recupere_continent (@nomPays nvarchar(15))
	returns nvarchar(100)
as
	begin
		declare
		@TSQL as nvarchar(4000),
		@continent as nvarchar(100);

		SELECT @TSQL = N'SELECT @ContinentOut = continent FROM OPENQUERY(ORACLE,''SELECT continent FROM system.corrpayscont WHERE lower(country) = lower(''''' + @nomPays + ''''')'')'
		exec sp_executesql 
		@TSQL, 
		N'@ContinentOut nvarchar(100) OUT', 
		@ContinentOut=@continent OUT

		return @continent;
	end
go

create procedure proc_maj_clients
as
	begin
		declare
		@curseurClientsNW as cursor,	-- Curseur des clients dans Northwind.
		@idClientDC as int,				-- ID du client dans la dimension client.
		@nomContact as nvarchar(30),
		@adresse as nvarchar(60),
		@nomVille as nvarchar(15),
		@nomPays as nvarchar(15),
		@nbOccurences as int;
		
		set @curseurClientsNW = cursor for
			select contactName, city, country, address
			from northwind.dbo.customers;
			
		open @curseurClientsNW;
		fetch @curseurClientsNW into @nomContact, @nomVille, @nomPays, @adresse;
		
		while @@fetch_status = 0
		begin
			-- Compte le nombre d'occurences du client dans la dimension client.
			set @nbOccurences = (
				select count(*) from tp2_entrepot.dbo.dimension_client
				where nom_contact=@nomContact and nom_ville=@nomVille and nom_pays=@nomPays
			);
			
			-- S'il n'y a pas d'occurences le client est ajouté à la dimension client.
			-- Sinon pour chaque occurences le client est ajouté ayant comme clé étrangère la clé primarei de celui qui le précède.
			-- (principe de liste chaînée)
			if @nbOccurences = 0
				insert into tp2_entrepot.dbo.dimension_client (nom_contact, nom_ville, nom_pays, continent) values (
					@nomContact, @nomVille, @nomPays, dbo.func_recupere_continent(@nomPays)
				);
			else
			begin
				set @idClientDC = (
					select id_client 
					from tp2_entrepot.dbo.dimension_client 
					where 
					id_ancient_client = (
						select top 1 id_ancient_client 
						from tp2_entrepot.dbo.dimension_client 
						where 
							nom_contact = @nomContact and 
							nom_ville = @nomVille and 
							nom_pays = @nomPays
						order by id_ancient_client desc
					) 
				);
				insert into tp2_entrepot.dbo.dimension_client (nom_contact, nom_ville, nom_pays, id_ancient_client) values (
					@nomContact, @nomVille, @nomPays, @idClientDC
				);
			end -- END ELSE
					
			fetch @curseurClientsNW into @nomContact, @nomVille, @nomPays, @adresse;
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
		@categorie as nvarchar(15),
		@pays as nvarchar(15),
		@systemeMesure as nvarchar(20),
		@nbOccurences as int;
		
		set @curseurProduits = cursor for
			select p.productName, s.companyName, c.categoryName, s.country, p.quantityPerUnit
			from northwind.dbo.products as p
				inner join northwind.dbo.suppliers as s on p.supplierId = s.supplierId
				inner join northwind.dbo.categories as c on p.categoryId = c.categoryId;
		
		open @curseurProduits;
		fetch @curseurProduits into @nomProduit, @nomFournisseur, @categorie, @pays, @systemeMesure;
			
		while @@fetch_status = 0
		begin
			set @nbOccurences = (
				select count(*) from tp2_entrepot.dbo.dimension_produit
				where 
					nom_produit=@nomProduit and 
					nom_fournisseur=@nomFournisseur and 
					categorie=@categorie and 
					pays_fournisseur=@pays and 
					systeme_mesure=@systemeMesure
			);
			
			if @nbOccurences = 0
				insert into tp2_entrepot.dbo.dimension_produit values (
					@nomProduit, @nomFournisseur, @categorie, @pays, @systemeMesure
				);
			
			fetch @curseurProduits into @nomProduit, @nomFournisseur, @categorie, @pays, @systemeMesure;
		end -- END WHILE
		
		close @curseurProduits;
	end
go