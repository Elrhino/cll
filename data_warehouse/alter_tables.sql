-- Ajout foreign key pour gérer les anciennes adresses d'un même client.
alter table dbo.dimension_client
add continent nvarchar(100) null;

alter table dbo.dimension_client
add id_ancient_client int null references dimension_client(id_client);