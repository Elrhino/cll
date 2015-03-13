-- Suppression des entrées.
delete from Fait_vente
delete from date_details
delete from dimension_client
delete from dimension_produit
delete from dimension_employe

-- Réinitialisation de l'auto-incrémentatio à 0.
DBCC CHECKIDENT (date_details, RESEED, 0)
DBCC CHECKIDENT (dimension_client, RESEED, 0)
DBCC CHECKIDENT (dimension_produit, RESEED, 0)
DBCC CHECKIDENT (dimension_employe, RESEED, 0)