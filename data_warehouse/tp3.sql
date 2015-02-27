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
				print('Rien à mettre à jour.');	
				return;
			end -- END IF
			
		open @curseurVentes;
		fetch @curseurVentes 
			into @unitPrice, @quantity, @orderId, @customerId, @employeeId, @productId;
			
		while @@fetch_status = 0
		begin
			insert into tp2_entrepot.dbo.dimension_client
			select contactName, city, country 
			from Northwind.dbo.Customers
			where customerId = @customerId;
				
		end -- END WHILE
	end
go
