-- =============================================
-- Author:		Renaud Lainé
-- Create date: 2015-02-27
-- Description:	TP3
-- =============================================

use Northwind;
go

-- Drop Procedures

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_maj_fv')
   DROP PROCEDURE proc_maj_fv
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_ajout_clients')
   DROP PROCEDURE proc_ajout_clients
GO

-- Procédure permettant la mise à jour du fait vente.
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

-- Procédure permettant d'ajouter des nouveaux clients.
create procedure proc_ajout_clients
as
	begin
		declare
		@curseurClients as cursor,
		@nomContact as nvarchar(30),
		@nomVille as nvarchar(15),
		@nomPays as nvarchar(15),
		@nbOccurences as int;
		
		set @curseurClients = cursor for
			select contactName, city, country
			from northwind.dbo.customers;
			
		open @curseurClients;
		fetch @curseurClients into @nomContact, @nomVille, @nomPays;
		
		while @@fetch_status = 0
		begin
			set @nbOccurences = (
				select count(*) from tp2_entrepot.dbo.dimension_client
				where nom_contact=@nomContact and nom_ville=@nomVille and nom_pays=@nomPays
			);
			
			if @nbOccurences = 0
				insert into tp2_entrepot.dbo.dimension_client (nom_contact, nom_ville, nom_pays) values (
					@nomContact, @nomVille, @nomPays
				);
					
			fetch @curseurClients into @nomContact, @nomVille, @nomPays;
		end -- END WHILE
		
		close @curseurClients;
	end
go

-- Procédure permettant d'ajouter des nouveaux produits.
create procedure proc_ajout_produits
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