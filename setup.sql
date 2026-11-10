-- Cole tudo isto no Supabase: SQL Editor > New query > Run

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null check (char_length(display_name) between 1 and 60),
  bio text not null default '' check (char_length(bio) <= 500),
  goals text not null default '' check (char_length(goals) <= 1500)
);

create table topics (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  day date not null,
  title text not null check (char_length(title) between 1 and 120),
  created_at timestamptz not null default now()
);
create index on topics (user_id, day);

-- Segurança: todos leem, mas só o dono altera os próprios dados
alter table profiles enable row level security;
alter table topics enable row level security;

create policy "perfis visiveis" on profiles for select using (true);
create policy "editar meu perfil" on profiles for update using (auth.uid() = id);
create policy "assuntos visiveis" on topics for select using (true);
create policy "criar meus assuntos" on topics for insert with check (auth.uid() = user_id);
create policy "apagar meus assuntos" on topics for delete using (auth.uid() = user_id);

-- Cria o perfil automaticamente quando uma conta nova é criada
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name)
  values (new.id, lower(new.raw_user_meta_data->>'username'), new.raw_user_meta_data->>'display_name');
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();
