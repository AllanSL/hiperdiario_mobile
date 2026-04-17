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

-- ==========================================
-- CATÁLOGO DE MEDICAMENTOS (FARMÁCIA SUS)
-- ==========================================

-- 1. Criação do Catálogo Padrão SUS
CREATE TABLE IF NOT EXISTS medicine_catalog (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  active_principle text NOT NULL,    
  strength text NOT NULL,            
  form text NOT NULL,                
  category text NOT NULL,            
  dispensing_unit text NOT NULL,     
  reference_box_qty integer,         
  created_at timestamptz DEFAULT now()
);

-- 2. Inserção dos dados que mapeamos
INSERT INTO medicine_catalog (active_principle, strength, form, category, dispensing_unit, reference_box_qty) VALUES
-- HIPERTENSÃO
('Atenolol', '25 mg', 'comprimido', 'Hipertensão', 'comprimido', 30), 
('Atenolol', '50 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Atenolol', '100 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Besilato de anlodipino', '5 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Besilato de anlodipino', '10 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Captopril', '25 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Carvedilol', '3,125 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Carvedilol', '6,25 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Carvedilol', '12,5 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Carvedilol', '25 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Cloridrato de hidralazina', '25 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Cloridrato de hidralazina', '50 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Cloridrato de propranolol', '10 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Cloridrato de propranolol', '40 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Cloridrato de verapamil', '80 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Cloridrato de verapamil', '120 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Cloridrato de verapamil', '2,5 mg/mL', 'solução injetável', 'Hipertensão', 'ampola', 1),
('Espironolactona', '25 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Espironolactona', '100 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Furosemida', '40 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Furosemida', '10 mg/mL', 'solução injetável', 'Hipertensão', 'ampola', 1),
('Hidroclorotiazida', '12,5 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Hidroclorotiazida', '25 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Losartana Potássica', '50 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Maleato de enalapril', '5 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Maleato de enalapril', '10 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Maleato de enalapril', '20 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Mesilato de doxazosina', '2 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Mesilato de doxazosina', '4 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Metildopa', '250 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),
('Nifedipino', '10 mg', 'cápsula ou comprimido', 'Hipertensão', 'unidade', 30),
('Succinato de metoprolol', '25 mg', 'comprimido de liberação prolongada', 'Hipertensão', 'comprimido', 30),
('Succinato de metoprolol', '50 mg', 'comprimido de liberação prolongada', 'Hipertensão', 'comprimido', 30),
('Succinato de metoprolol', '100 mg', 'comprimido de liberação prolongada', 'Hipertensão', 'comprimido', 30),
('Tartarato de metoprolol', '100 mg', 'comprimido', 'Hipertensão', 'comprimido', 30),

-- DIABETES (Comprimidos)
('Glibenclamida', '5 mg', 'comprimido', 'Diabetes', 'comprimido', 30),
('Cloridrato de metformina', '500 mg', 'comprimido', 'Diabetes', 'comprimido', 30),
('Cloridrato de metformina', '850 mg', 'comprimido', 'Diabetes', 'comprimido', 30),
('Cloridrato de metformina', '500 mg', 'comprimido de ação prolongada', 'Diabetes', 'comprimido', 30),

-- DIABETES (Insulinas)
('Insulina Humana NPH', '100 UI/ml', 'suspensão injetável', 'Diabetes', 'frasco-ampola 10 ml', 1),
('Insulina Humana NPH', '100 UI/ml', 'suspensão injetável', 'Diabetes', 'frasco-ampola 5 ml', 1),
('Insulina Humana NPH', '100 UI/ml', 'suspensão injetável', 'Diabetes', 'refil 3ml (carpule)', 1),
('Insulina Humana NPH', '100 UI/ml', 'suspensão injetável', 'Diabetes', 'refil 1,5ml (carpule)', 1),
('Insulina Humana Regular', '100 UI/ml', 'solução injetável', 'Diabetes', 'frasco-ampola 10 ml', 1),
('Insulina Humana Regular', '100 UI/ml', 'solução injetável', 'Diabetes', 'frasco-ampola 5 ml', 1),
('Insulina Humana Regular', '100 UI/ml', 'solução injetável', 'Diabetes', 'refil 3ml (carpules)', 1),
('Insulina Humana Regular', '100 UI/ml', 'solução injetável', 'Diabetes', 'refil 1,5ml (carpules)', 1);

-- 3. Tabela de Controle da Dispensação mensal
CREATE TABLE IF NOT EXISTS medicine_dispensations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id bigint REFERENCES users(id),
  catalog_id uuid REFERENCES medicine_catalog(id),
  ubs_cnes text NOT NULL,                    
  dispensed_quantity integer NOT NULL,       
    frequency_label text,
    scheduled_times jsonb,

