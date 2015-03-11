-- Ajout foreign key pour gérer les anciennes adresses d'un même client.
alter table dbo.dimension_client
add id_ancient_client int null references dimension_client(id_client);

alter table dbo.dimension_client
add nom_compagnie nvarchar(40) null;

alter table dbo.dimension_client
add identificateur nchar(5) null;

alter table dbo.dimension_produit
add identifiant int null;

alter table dbo.dimension_produit
add id_ancient_produit int null references dimension_produit(id_produit);