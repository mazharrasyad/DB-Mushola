drop table if exists keuangan cascade;
drop table if exists belanja cascade;
drop table if exists inventaris cascade;
drop table if exists penyewa cascade;
drop table if exists donatur cascade;
drop table if exists pengurus cascade;
drop table if exists laporan cascade;
drop table if exists laporan_keuangan cascade;
drop table if exists peminjaman cascade;
drop table if exists peminjaman_detail cascade;

create table keuangan(
id serial primary key, 
total double precision);

create table belanja(
id serial primary key, 
nama varchar(45), 
harga double precision,
keuangan_id int references keuangan(id));

create table inventaris( 
nama varchar(45) primary key, 
jumlah int, 
status varchar(45));

create table pengurus (
id serial primary key, 
nama varchar(45), 
tgl_lahir date, 
alamat varchar(45));

create table penyewa (
kode varchar(10), 
total_meminjam int default 0,
primary key(id)) 
inherits(pengurus);

create table donatur (
pekerjaan varchar(45), 
jumlah_donasi double precision,
keuangan_id int references keuangan(id),
primary key(id)) 
inherits(pengurus);

create table laporan (
id serial primary key,
inventaris_nama varchar(45) references inventaris(nama),
belanja_id int references belanja(id),
tanggal timestamp default now());

create table laporan_keuangan (
keuangan_id int references keuangan(id),
laporan_id int references laporan(id));

create table peminjaman (
id serial primary key,
penyewa_id int references penyewa(id),
tanggal timestamp default now());

create table peminjaman_detail (
peminjaman_id int references peminjaman(id),
inventaris_nama varchar(45) references inventaris(nama),
jumlah int,
status varchar(45) default 'Menunggu',
tgl_pengembalian date);

create or replace function
produk(varchar,real,int) returns void as
$$
	declare
		nama alias for $1;
		harga alias for $2;
		keuangan alias for $3;
	begin
		insert into belanja values
		(default,nama,harga,keuangan);		
	end
$$ language plpgsql;

create or replace function 
beli() returns trigger as
$$
	declare
		i int;
		namax text;	
	begin
			i = 0;
		loop
			select into namax nama from inventaris limit 1 offset i;
		
			if new.nama = namax then
				update inventaris set jumlah = jumlah + 1
				where nama = new.nama;
			
				update keuangan set total = total - new.harga
				where id = new.keuangan_id;
			
				insert into laporan values
				(default,new.nama,new.id,default);
			
				exit;
			else
				insert into inventaris values
				(new.nama,1,'Tersedia');
			
				insert into laporan values
				(default,new.nama,new.id,default);
			
				exit;
			end if;
		
		end loop;
	
		return new;		
	end
$$ language plpgsql;

create or replace function 
catat() returns trigger as
$$
	declare
		keuanganx int;
	begin
		select into keuanganx keuangan_id from belanja where id = new.id;
		
		insert into laporan_keuangan values
		(keuanganx,new.id);

		return new;
	end
$$ language plpgsql;

create or replace function 
donasi() returns trigger as
$$
	begin
		update keuangan set total = total + new.jumlah_donasi
		where id = new.keuangan_id;

		return new;
	end
$$ language plpgsql;

create or replace function
minjam(int,varchar,int) returns void as
$$
	declare		
		penyewax alias for $1;
		inventarisx alias for $2;
		jumlahx alias for $3;
		idx int;
	begin
		select into idx id from peminjaman order by id desc limit 1;		
		
		if idx is null then
			idx = 1;
		else
			idx = idx + 1;
		end if;		
		
		insert into peminjaman values
		(idx, penyewax, default);
	
		insert into peminjaman_detail values
		(idx, inventarisx, jumlahx, default, null);			
	end
$$ language plpgsql;

create or replace function 
cek() returns trigger as
$$
	declare
		jumlahx int;
	begin
		select into jumlahx jumlah from inventaris where nama = new.inventaris_nama;	
		
		if 0 < jumlahx then
			if (jumlahx - new.jumlah) < 0 then
				return old;
			elseif (jumlahx - new.jumlah) != 0 then
				update inventaris set jumlah = jumlah - new.jumlah
				where nama = new.inventaris_nama;								
			
				update penyewa set total_meminjam = total_meminjam + 1
				where id = new.peminjaman_id;
			else
				update inventaris set jumlah = jumlah - new.jumlah
				where nama = new.inventaris_nama;								
			
				update penyewa set total_meminjam = total_meminjam + 1
				where id = new.peminjaman_id;
			
				update inventaris set status = 'Tidak Tersedia'
				where nama = new.inventaris_nama;
			end if;
		
			return new;
		end if;			
	
		return old;
	end
$$ language plpgsql;

create or replace function 
proses() returns trigger as
$$
	begin									
		update peminjaman_detail set 
		status = 'Berhasil',
		tgl_pengembalian = current_date + integer '7'
		where inventaris_nama = old.nama;
	
		return new;
	end
$$ language plpgsql;

create trigger trig_donasi after 
insert on donatur for each row execute
procedure donasi();

create trigger trig_beli after 
insert on belanja for each row execute
procedure beli();

create trigger trig_catat after 
insert on laporan for each row execute
procedure catat();

create trigger trig_cek after 
insert on peminjaman_detail for each row execute
procedure cek();

create trigger trig_proses after 
update on inventaris for each row execute
procedure proses();

select * from keuangan;
select * from belanja;
select * from inventaris;
select * from laporan;
select * from laporan_keuangan;
select * from donatur;

select * from penyewa;
select * from peminjaman;
select * from peminjaman_detail;
select * from inventaris;

begin transaction

insert into keuangan values
(1,10000000),
(2,20000000);

select produk('Sajadah',100000,1);
select produk('Sajadah',200000,2);
select produk('Alquran',300000,1);

insert into donatur values
(default,'Akbar','1999-12-31','Depok','Pengacara',5000000),
(default,'Fathan','2000-01-10','Cilodong','Hakim',2000000);

insert into penyewa values
(1,'Ulin','1988-10-30','Tanah Abang','P1',default);

select minjam(1,'Sajadah',1);
select minjam(1,'Alquran',2);

rollback;
commit;