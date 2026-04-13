-- Supabase schema for HiperDiário (run in Supabase SQL editor)

-- Tabela de usuários / perfis
create table if not exists users (
  id bigserial primary key,
  remote_id text,
  name text,
  cpf text not null unique,
  birth_date date,
  gender text,
  diseases text[] default '{}',
  phone text,
  email text,
  emergency_contact jsonb,
  uf text,
  municipio_ibge bigint,
  ubs_cnes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table users add column if not exists diseases text[] default '{}';
alter table users add column if not exists emergency_contact jsonb;
alter table users add column if not exists ubs_cnes text;

-- Tabela de medicamentos
create table if not exists medications (
  id bigserial primary key,
  remote_id text,
  name text not null,
  owner_id uuid,
  brand text,
  strength text,
  form text,
  dosage_instructions text,
  frequency jsonb,
  total_doses integer default 0,
  doses_per_intake numeric default 1,
  stock integer default 0,
  low_stock_threshold integer default 0,
  active boolean default true,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_taken_at timestamptz
);
create index if not exists idx_medications_name on medications (lower(name));

-- Enable Row Level Security (RLS) for medications and create a basic policy
-- Make sure to run these statements after creating the table in Supabase SQL editor.
alter table medications enable row level security;
-- Some Postgres versions (and the Supabase SQL editor) don't accept
-- `CREATE POLICY IF NOT EXISTS`. Use DROP IF EXISTS then CREATE instead.
drop policy if exists medications_owner_policy on medications;
create policy medications_owner_policy on medications
  for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Tabela de consultas / agendamentos
create table if not exists appointments (
  id bigserial primary key,
  remote_id text,
  patient_id bigint references users(id),
  date_time timestamptz not null,
  specialty text,
  notes text,
  establishment_id bigint,
  is_synced boolean default false,
  status text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_appointments_date on appointments (date_time);

-- Tabela de CNES (estabelecimentos)
create table if not exists cnes_establishments (
  id bigserial primary key,
  cnes_id text,
  name text,
  address text,
  city_ibge bigint,
  uf text,
  phone text,
  latitude double precision,
  longitude double precision,
  last_updated timestamptz default now()
);
create index if not exists idx_cnes_cnesid on cnes_establishments (cnes_id);

-- Tabela de municipios (cache)
create table if not exists municipios (
  id bigserial primary key,
  ibge_id bigint unique,
  name text,
  uf text,
  last_updated timestamptz default now()
);
create index if not exists idx_municipios_uf on municipios (uf);

-- Recuperação de senha
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION recuperar_senha_paciente(
  p_cpf text,
  p_nova_senha text,
  p_email text DEFAULT NULL,
  p_nome text DEFAULT NULL,
  p_data_nascimento date DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER -- Permite a função modificar o schema 'auth'
AS $$
DECLARE
  v_usuario record;
  v_auth_user_id uuid;
BEGIN
  -- Busca os dados originais na tabela do paciente
  SELECT * INTO v_usuario FROM public.users WHERE cpf = p_cpf;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuário não encontrado.';
  END IF;

  -- Busca o ID respectivo na conta de autenticação (auth.users)
  SELECT id INTO v_auth_user_id FROM auth.users WHERE email = p_cpf || '@hiperdiario.app';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conta de autenticação não encontrada.';
  END IF;

  -- Validação por E-mail
  IF p_email IS NOT NULL THEN
    IF p_email <> v_usuario.email THEN
      RAISE EXCEPTION 'O e-mail informado não corresponde ao cadastrado.';
    END IF;
    
  -- Validação por Nome e Data de Nascimento  
  ELSIF p_nome IS NOT NULL AND p_data_nascimento IS NOT NULL THEN
    IF lower(trim(p_nome)) <> lower(trim(v_usuario.name)) OR p_data_nascimento <> v_usuario.birth_date THEN
      RAISE EXCEPTION 'Os dados informados não conferem com nossa base de dados.';
    END IF;
    
  -- Sem dados suficientes
  ELSE
    RAISE EXCEPTION 'É necessário informar e-mail ou nome e data de nascimento válidos.';
  END IF;

  -- Se validado, aplica a nova senha direto na tabela restrita do Supabase Auth
  UPDATE auth.users 
  SET encrypted_password = crypt(p_nova_senha, gen_salt('bf'))
  WHERE id = v_auth_user_id;

  RETURN TRUE;
END;
$$;

-- Função para obter o nome do paciente durante a recuperação de senha, usando CPF e data de nascimento como validação.
CREATE OR REPLACE FUNCTION obter_nome_paciente_recuperacao(p_cpf text, p_data_nascimento date)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER 
AS $$
DECLARE
  v_nome text;
BEGIN
  -- Tenta buscar o nome cujo cpf e data de nascimento batem perfeitamente.
  SELECT name INTO v_nome 
  FROM public.users 
  WHERE cpf = p_cpf AND birth_date = p_data_nascimento;

  -- Se não for encontrado nenhum usuário com essas exatas correspondências, devolve erro
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Dados não conferem.';
  END IF;

  RETURN v_nome;
END;
$$;