-- Ajout foreign key pour g�rer les anciennes adresses d'un m�me client.
alter table dbo.dimension_client
add continent nvarchar(100) null;

alter table dbo.dimension_client
add id_ancient_client int null references dimension_client(id_client);