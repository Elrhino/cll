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
		@curseurVentes as cursor;
		
		set @dateDerniereVenteFV = (select top 1 date_vente
									 from tp2_entrepot.dbo.date_details 
									 order by date_vente desc);
									 
		set @dateDerniereVenteNW = (select top 1 orderDate
								  from northwind.dbo.orders
								  order byr orderDate desc);
								  
		if @dateDerniereVenteNW > @dateDerniereVenteFV
			set @curseurVentes = cursor for
				select 
	end
go
