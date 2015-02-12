use Northwind;
Go
/*
sp_configure 'show advanced', 1
reconfigure
GO

sp_configure 'Ad Hoc Distributed Queries', 1
reconfigure
GO

sp_configure 'show advanced',0
reconfigure
GO

select * FROM OPENDATASOURCE('MSDASQL', 'Data Source=ORACLE;user id=scott;password=tiger').system.dbo.corrpayscont
Go
*/
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_insert_fait')
   DROP PROCEDURE proc_insert_fait
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'proc_insert_client')
   DROP PROCEDURE proc_insert_client
GO

-- TODO: A completer à la fin.
create procedure proc_insert_fait
as
	begin
		declare
		@OrdersCursor as cursor,
		@unitPrice as money,
		@quantity as smallint
		
		set @OrdersCursor = cursor for
		select od.unitPrice, od.quantity
			from [Order Details] as od 
				inner join orders as o on od.orderId = o.orderId
				inner join customers as c on o.customerId = c.customerId
				inner join employees as e on o.employeeId = e.employeeId
				inner join products as p on od.productId = p.productId;
				
		open @OrdersCursor;
		fetch next from @OrdersCursor;
		while @@fetch_status = 0
		begin
			fetch next from @OrdersCursor into @unitPrice, @quantity;
			insert into [tp2_entrepot].dbo.fait_vente (prix_vente, quantite)
				values (@unitPrice, @quantity);
		end
			
	end
go

create procedure proc_insert_client
as
	begin
		declare
		@CurseurClient as cursor;
		
		set @CurseurClient = cursor for
		select customerId, contactName, city, country 
			from Northwind.dbo.Customers;
	end
go

create procedure proc_insert_produit
as
	begin
		declare
		@ProductsCursor as cursor;
		
		set @ProductsCursor = cursor for
		select p.productName, s.companyName, c.categoryName, s.country, p.quantityPerUnit
			from products as p
				inner join suppliers as s on p.supplierid = s.supplierId
				inner join categories as c on p.categoryId = c.categoryId;
	end
go

exec proc_insert_produit