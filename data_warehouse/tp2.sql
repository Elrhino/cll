-- =============================================
-- Author:		Renaud Lainé
-- Create date: 2015-02-05
-- Description:	TP2
-- =============================================

use Northwind;
Go

--select * FROM OPENDATASOURCE('ORACLE', 'Data Source=ORACLE;user id=scott;password=tiger').system.dbo.corrpayscont
--Go

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_insert_client')
   DROP PROCEDURE proc_insert_client
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_insert_produit')
   DROP PROCEDURE proc_insert_produit
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_insert_employe')
   DROP PROCEDURE proc_insert_employe
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_insert_fait')
   DROP PROCEDURE proc_insert_fait
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'V' AND name = 'vue_employes')
   DROP VIEW vue_employes
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'V' AND name = 'vue_ventes_mensuelles')
   DROP VIEW vue_ventes_mensuelles
GO

create procedure proc_insert_client
as
	begin
		declare
		@CurseurClient as cursor,
		@nomContact as nvarchar(30),
		@nomVille as nvarchar(15),
		@nomPays as nvarchar(15),
		@identificateur as nchar(5),
		@continent as nvarchar(100),
		@TSQL NVARCHAR(4000);
		
		set @CurseurClient = cursor for
		select contactName, city, country, customerID
			from Northwind.dbo.Customers;
			
		open @CurseurClient;
		fetch next from @CurseurClient into @nomContact, @nomVille, @nomPays, @identificateur
			while @@fetch_status = 0 begin
				
				SELECT @TSQL = N'SELECT @ContinentOut = continent FROM OPENQUERY(ORACLE,''SELECT continent FROM system.corrpayscont WHERE lower(country) = lower(''''' + @nomPays + ''''')'')'
				exec sp_executesql 
				@TSQL, 
				N'@ContinentOut nvarchar(100) OUT', 
				@ContinentOut=@continent OUT
				
				insert into tp2_entrepot.dbo.dimension_client (nom_contact, nom_ville, nom_pays, continent, identificateur)
					values (@nomContact, @nomVille, @nomPays, @continent, @identificateur);
				fetch next from @CurseurClient into @nomContact, @nomVille, @nomPays, @identificateur
			end
		close @CurseurClient;
	end
go

create procedure proc_insert_produit
as
	begin
		declare
		@ProductsCursor as cursor,
		@nomProduit as nvarchar(40),
		@nomFournisseur as nvarchar(40),
		@categorie as nvarchar(15),
		@pays as nvarchar(15),
		@mesure as nvarchar(20);
		
		set @ProductsCursor = cursor for
		select p.productName, s.companyName, c.categoryName, s.country, p.quantityPerUnit
			from products as p
				inner join suppliers as s on p.supplierid = s.supplierId
				inner join categories as c on p.categoryId = c.categoryId;
		open @ProductsCursor;
		fetch next from @ProductsCursor into @nomProduit, @nomFournisseur, @categorie, @pays, @mesure
			while @@fetch_status = 0 begin
				insert into tp2_entrepot.dbo.dimension_produit values (
					@nomProduit, @nomFournisseur, @categorie, @pays, @mesure
				);
				fetch next from @ProductsCursor into @nomProduit, @nomFournisseur, @categorie, @pays, @mesure
			end
		close @ProductsCursor;
	end
go

create procedure proc_insert_employe
as
	begin
		declare
		@EmployeesCursor as cursor,
		@nomEmploye as nvarchar(30),
		@titre as nvarchar(30),
		@nomPays as nvarchar(15),
		@indicateur as int;
		
		set @EmployeesCursor = cursor for
		select 
			firstName + ' ' + lastName as 'Nom de l''employé', 
			title as 'Titre', 
			country as 'Pays',
			reportsTo as 'Indicateur'
		from employees;
			
		open @EmployeesCursor;
		fetch next from @EmployeesCursor into @nomEmploye, @titre, @nomPays, @indicateur
			while @@fetch_status = 0 begin
				insert into tp2_entrepot.dbo.dimension_employe values (
					@nomEmploye, @titre, @nomPays, @indicateur
				);
				fetch next from @EmployeesCursor into @nomEmploye, @titre, @nomPays, @indicateur
			end
		close @EmployeesCursor;
	end
go

/* 
Contient le prix de vente et la quantité vendue de chaque produit de chaque commande actuellement 
dans la base de données Northwind ainsi que les références aux tables de dimensions.
*/
create procedure proc_insert_fait
as
	begin
		declare
		@CurseurVentes as cursor,
		@unitPrice as money,
		@quantity as smallint,
		
		@contactName as nvarchar(30),
		@productName as nvarchar(40),
		@employeeName as nvarchar(30),
		@employeeTitle as nvarchar(30),
		@orderDate as date,
		@idDC as int,						-- ID dimension client
		@idDP as int,						-- ID dimension produit
		@idDE as int,						-- ID dimension employe
		@idDate as int;						-- ID date_details
		
		set @CurseurVentes = cursor for
		select 
			od.unitPrice as 'Prix unitaire',
			od.quantity as 'Quantité',
			c.contactName as 'Nom du contact', 
			p.productName as 'Nom de produit',
			e.firstName + ' ' + e.lastName as 'Nom de l''employé', 
			e.title as 'Titre',
			o.OrderDate
		from Orders as o 
			inner join [Order Details] as od on o.orderId = od.orderId
			inner join products as p on p.productId = od.productId
			inner join customers as c on c.customerId = o.customerId
			inner join employees as e on e.employeeId = o.employeeId
				
		open @CurseurVentes;
		fetch next from @CurseurVentes 
		into @unitPrice, @quantity, @contactName, @productName, @employeeName, @employeeTitle, @orderDate;
			
		while @@fetch_status = 0
		begin
			fetch next from @CurseurVentes 
			into @unitPrice, @quantity, @contactName, @productName, @employeeName, @employeeTitle, @orderDate;
			
			set @idDC = (select id_client from tp2_entrepot.dbo.dimension_client where nom_contact = @contactName);
			set @idDP = (select id_produit from tp2_entrepot.dbo.dimension_produit where nom_produit = @productName);
			set @idDE = (select id_employe from tp2_entrepot.dbo.dimension_employe where nom_employe = @employeeName and titre = @employeeTitle);
			set @idDate = (select id_date from tp2_entrepot.dbo.date_details where date_vente = @orderDate);

			insert into tp2_entrepot.dbo.fait_vente values (@unitPrice, @quantity, @idDC, @idDP, @idDE, @idDate);			
		end
		
		close @CurseurVentes;
	end
go

create view vue_employes
as
	select annee_financiere, nom_employe, SUM(prix_vente) as prix 
	from tp2_entrepot.dbo.fait_vente as fv 
		inner join tp2_entrepot.dbo.dimension_employe as de on fv.id_employe = de.id_employe
		inner join tp2_entrepot.dbo.date_details as dd on fv.id_date = dd.id_date
	group by annee_financiere, nom_employe
go

create view vue_ventes_mensuelles
as
	select SUM(prix_vente) as 'Total des ventes', mois, continent from tp2_entrepot.dbo.fait_vente as fv
		inner join tp2_entrepot.dbo.date_details as dd on fv.id_date = dd.id_date
		inner join tp2_entrepot.dbo.dimension_client as dc on fv.id_client = dc.id_client
	where datepart(year, dd.date_vente) = 2012 or datepart(year, dd.date_vente) = 2013
	group by mois, continent
go

-- Exécution des procédures stockées.
exec tp2_entrepot.dbo.remplirDates;
exec proc_insert_client;
exec proc_insert_produit;
exec proc_insert_employe;
exec proc_insert_fait;
select * from vue_employes order by annee_financiere, nom_employe
select * from vue_ventes_mensuelles order by mois