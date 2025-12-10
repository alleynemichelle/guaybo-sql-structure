CREATE SCHEMA IF NOT EXISTS app_core;

-- ================================================
-- Extensions
-- ================================================
CREATE EXTENSION IF NOT EXISTS ltree;

-- ================================================
-- Schemas
-- ================================================
CREATE SCHEMA IF NOT EXISTS app_core;

-- ================================================
-- Types
-- ================================================
CREATE TYPE app_core.common_status AS ENUM ('ACTIVE', 'INACTIVE');
CREATE TYPE app_core.product_date_status AS ENUM ('DEPENDS_ON_DATE', 'MANUALLY_OPENED', 'MANUALLY_CLOSED');
CREATE TYPE app_core.kyc_session_status AS ENUM ('NOT_STARTED', 'APPROVED', 'DECLINED', 'IN_REVIEW', 'ABANDONED', 'EXPIRED', 'KYC_EXPIRED', 'MAX_RETRIES_REACHED');
CREATE TYPE app_core.product_status AS ENUM ('PUBLISHED', 'DRAFT', 'PAUSED', 'DELETED', 'CLOSED');
CREATE TYPE app_core.user_access_status AS ENUM ('ACTIVE', 'CONFIRMATION_PENDING', 'EXPIRED', 'REVOKED', 'INACTIVE', 'DELETED', 'LATE_PAYMENT');

-- ================================================
-- Tabla STATUS (global o específica por entity_type)
-- ================================================
CREATE TABLE app_core.status (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,       -- ej: 'ACTIVE', 'INACTIVE', 'PENDING'
    description VARCHAR(255),                -- explicación breve
    entity_type VARCHAR(100) NOT NULL,       -- ej: 'host', 'multimedia', 'purchase_order'
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE app_core.product_type (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  total_products INT DEFAULT 0,
  icon varchar(50),
  status app_core.common_status NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE app_core.category (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  name VARCHAR(300) NOT NULL,
  total_products INT DEFAULT 0,
  thumbnail varchar(1000),
  icon varchar(50),
  category_id BIGINT REFERENCES app_core.category(id),
  status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ================================================
-- Lookup tables (para reemplazar enums como VARCHAR)
-- ================================================

CREATE TABLE app_core.meeting_platform (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key VARCHAR(50) NOT NULL UNIQUE,   -- 'ZOOM', 'MEET', 'TEAMS'
    description VARCHAR(255)
);

-- ================================================
-- Tabla APP_SETTINGS (Configuraciones globales)
-- ================================================
CREATE TABLE app_core.app_settings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    settings_group VARCHAR(100) NOT NULL,                  -- logical group identifier
    key VARCHAR(100) NOT NULL,                    -- example: 'TAX_CONFIG'
    value VARCHAR(100),                           -- percentage or fixed rate
    value_type VARCHAR(50) NOT NULL,               -- 'PERCENTAGE', 'FIXED'
    country VARCHAR(10),                          -- ISO country code
    description VARCHAR(255),
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ================================================
-- Tabla CURRENCY
-- ================================================
CREATE TABLE app_core.currency (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,   -- 'USD', 'VES', 'EUR'
    symbol VARCHAR(10) NOT NULL,        -- '$', 'Bs.', '€'
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ================================================
-- Tabla ROLE
-- ================================================
CREATE TABLE app_core.role (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,       -- Ej: 'owner', 'admin', 'editor', 'viewer'
    description VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ================================================
-- Tabla PAYMENT_METHOD
-- ================================================
CREATE TABLE app_core.payment_method (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key VARCHAR(50) NOT NULL UNIQUE,     -- Ej: 'MOBILE_PAYMENT', 'PAYPAL', 'ZELLE'
    icon VARCHAR(50),
    requires_coordination BOOLEAN DEFAULT FALSE,
    requires_receipt BOOLEAN DEFAULT FALSE,
    processor_type VARCHAR(50) NOT NULL, -- 'MANUAL', 'AUTOMATIC_MOBILE_PAYMENT', 'PAYPAL', 'STRIPE', 'ZINLI'
    automatic BOOLEAN DEFAULT FALSE,
    currency_id BIGINT NOT NULL REFERENCES app_core.currency(id),
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);


CREATE TABLE app_core.payment_fee_rule (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_method_id BIGINT NOT NULL REFERENCES app_core.payment_method(id) ON DELETE CASCADE,
  direction VARCHAR(10) NOT NULL CHECK (direction IN ('IN', 'OUT')),  -- tipo de transacción
  fee_percent BIGINT DEFAULT 0,
  fee_fixed BIGINT DEFAULT 0,
  assumed_by VARCHAR(20) DEFAULT 'HOST',  -- quién la asume
  country VARCHAR(10),  -- opcional: si alguna pasarela cambia por país
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);





CREATE TABLE app_core.billing_plan (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    key VARCHAR(100) NOT NULL UNIQUE,   -- 'BASIC', 'PREMIUM', 'ENTERPRISE'
    description VARCHAR(1000),          

    features JSONB,  
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE app_core.plan_breakdown (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    billing_plan_id BIGINT NOT NULL REFERENCES app_core.billing_plan(id) ON DELETE CASCADE,

    billing_type VARCHAR(50) NOT NULL, -- 'STANDARD', 'MEDIA_ACCESS', 'VIDEO_ACCESS'
    key VARCHAR(100) NOT NULL,   -- 'PLAN_PERCENTAGE_COMMISSION', 'PLAN_FIXED_COMMISSION'
    type VARCHAR(50) NOT NULL,   -- 'PERCENTAGE', 'FIXED', 'SUBSCRIPTION'
    amount BIGINT NOT NULL       -- monto en céntimos
);


-- ================================================
-- Tabla MULTIMEDIA
-- ================================================
CREATE TABLE app_core.multimedia (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    -- Propietario: host o user
    host_id BIGINT,
    user_id BIGINT,

    type VARCHAR(50) NOT NULL,    -- 'image', 'video'
    source VARCHAR(50) NOT NULL,  -- 'upload', 'youtube', 'drive', 'bunny'
    size BIGINT,           -- BIGINT bytes
    duration DECIMAL(10,2),       -- minutos
    filename VARCHAR(500),
    path VARCHAR(1000),
    description VARCHAR(1000),
    usage_type VARCHAR(50),  -- 'profile', 'banner', 'preview', 'thumbnail'
    order_index INT,

    file_id VARCHAR(255),              -- id en storage externo
    processing_status VARCHAR(50),   -- 'TRANSCODING', 'READY'
    encode_progress INT,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    status app_core.common_status NOT NULL DEFAULT 'ACTIVE'
);

-- ================================================
-- Tabla HOST
-- ================================================
CREATE TABLE app_core.host (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    commission_payer VARCHAR(50) NOT NULL DEFAULT 'HOST',
    logo_id BIGINT REFERENCES app_core.multimedia(id) ON DELETE SET NULL,
    
    name VARCHAR(255) NOT NULL,
    alias VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,

    collection_id VARCHAR(255),
    description TEXT, 
    
    phone_code VARCHAR(10),
    phone_number VARCHAR(20),
    timezone VARCHAR(100),

    rating DECIMAL(5,0),
    reviews INT,
    years_experience INT,

    -- Tags como JSONB
    tags JSONB, 

    -- Estados
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    logo_cache JSONB,
    featured_media_cache JSONB,
    banner_cache JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    migrated_at TIMESTAMPTZ
);


CREATE TABLE app_core.discount (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    migration_id VARCHAR(255),
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    host_id BIGINT REFERENCES app_core.host(id) ON DELETE CASCADE,
    
    name VARCHAR(255),
    description TEXT, --cambiado VARCHAR(1000),
    owner_type VARCHAR(50) NOT NULL DEFAULT 'APP', -- 'APP', 'HOST'

    percentage INT NOT NULL,        -- porcentaje del descuento
    -- offer_type VARCHAR(50) DEFAULT 'DISCOUNT',  -- 'DISCOUNT', 'COUPON'

    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,

    code VARCHAR(100) NOT NULL,          -- código opcional (ej: SUMMER2025)
    max_capacity INT,           -- límite de usos totales
    total_orders INT DEFAULT 0,

    duration_quantity INT,      -- cantidad de duración en días
    duration_unit VARCHAR(50),  -- unidad de duración (ej: 'DAY', 'WEEK', 'MONTH', 'YEAR')
    conditions JSONB,           -- condiciones adicionales dinámicas (ej: {"currency": "USD"})

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ, 
    migrated_at TIMESTAMPTZ,

    UNIQUE(host_id, code)
);


-- ================================================
-- Tabla HOST_BILLING_PLAN_HISTORY (Historial de planes de facturación)
-- ================================================
CREATE TABLE app_core.host_billing_plan_history (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    billing_plan_id BIGINT NOT NULL REFERENCES app_core.billing_plan(id) ON DELETE RESTRICT,
    
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    
    started_at TIMESTAMPTZ NOT NULL,        -- cuando comenzó a usar este plan
    ended_at TIMESTAMPTZ,                   -- cuando terminó de usar este plan (NULL si está activo)
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);



-- ================================================
-- Tabla USER
-- ================================================
CREATE TABLE app_core.app_user (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255),
    email VARCHAR(255) UNIQUE NOT NULL,
    instagram_account VARCHAR(255),
    federated BOOLEAN DEFAULT FALSE,
    registered BOOLEAN DEFAULT FALSE,
    verified_email BOOLEAN DEFAULT FALSE,
    verified_kyc BOOLEAN DEFAULT FALSE,
    
    phone_code VARCHAR(10),
    phone_number VARCHAR(20),

    timezone VARCHAR(100),
    last_access TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    default_language VARCHAR(20) DEFAULT 'ES',

    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',

    is_host BOOLEAN DEFAULT FALSE,
    is_referrer BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    migrated_at TIMESTAMPTZ
);

-- Add FK after both tables exist to avoid creation-order issues
ALTER TABLE app_core.multimedia
    ADD CONSTRAINT multimedia_user_fk
    FOREIGN KEY (user_id) REFERENCES app_core.app_user(id) ON DELETE CASCADE;




-- ================================================
-- Tabla HOST_SOCIAL_MEDIA (Redes sociales normalizadas)
-- ================================================
CREATE TABLE app_core.host_social_media (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    
    platform VARCHAR(50) NOT NULL,     -- 'INSTAGRAM', 'FACEBOOK', 'X', 'TIKTOK', 'YOUTUBE', 'LINKEDIN', etc.
    username VARCHAR(255),              -- @username o handle
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',

    
    UNIQUE(host_id, platform, username)
);

-- ================================================
-- Tabla HOST_ANALYTICS (Pixels y trackers normalizados)
-- ================================================
CREATE TABLE app_core.host_analytics (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    
    provider VARCHAR(50) NOT NULL,      -- 'META_PIXEL', 'GOOGLE_ANALYTICS', 'GOOGLE_TAG_MANAGER', 'TIKTOK_PIXEL', etc.
    tracker_id VARCHAR(255) NOT NULL,   -- ID del pixel/tracker
    tracker_name VARCHAR(255),          -- Nombre descriptivo del tracker
    configuration JSONB,                -- Configuración específica del tracker
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    migrated_at TIMESTAMPTZ,
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    
    UNIQUE(host_id, provider, tracker_id)
);

-- ================================================
-- Relación N:M entre USER y HOST con ROLE
-- ================================================
CREATE TABLE app_core.host_user (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES app_core.role(id) ON DELETE RESTRICT,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    migrated_at TIMESTAMPTZ,
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',

    -- Garantiza que un usuario no se repita dentro del mismo host
    UNIQUE(host_id, user_id)
);

-- ================================================
-- Tabla CUSTOMER (relación usuario-host con info adicional)
-- ================================================
CREATE TABLE app_core.customer (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,
    total_orders INTEGER DEFAULT 0,
   -- tags JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    migrated_at TIMESTAMPTZ,
    UNIQUE(host_id, user_id)
);


CREATE TABLE app_core.customer_tag (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE, -- opcional, si las etiquetas son por host
  key VARCHAR(100) NOT NULL,       -- 'completed_form', 'attended_event', 'no_show'
  value VARCHAR(255),              -- nombre legible: 'Completó formulario'
  description TEXT,
  color VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  migrated_at TIMESTAMPTZ,
  UNIQUE(host_id, key)
);

CREATE TABLE app_core.customer_tag_relation (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES app_core.customer(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES app_core.customer_tag(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  migrated_at TIMESTAMPTZ,
  UNIQUE(customer_id, tag_id)
);

-- ================================================
-- Tabla HOST_BILLING_DISCOUNT
-- ================================================
CREATE TABLE app_core.host_billing_discount (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    discount_id BIGINT NOT NULL REFERENCES app_core.discount(id) ON DELETE CASCADE,
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ
);



CREATE TABLE app_core.product (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    category_id BIGINT REFERENCES app_core.category(id) ON DELETE SET NULL,
    product_type_id BIGINT NOT NULL REFERENCES app_core.product_type(id) ON DELETE CASCADE,

    name VARCHAR(500) NOT NULL,
    alias VARCHAR(500) NOT NULL,
    description TEXT, --cambiado VARCHAR(300),

    billing_type VARCHAR(50) NOT NULL, -- 'STANDARD', 'MEDIA_ACCESS', 'VIDEO_ACCESS'
    status app_core.product_status NOT NULL DEFAULT 'DRAFT',

    is_free BOOLEAN DEFAULT FALSE,
    timezone VARCHAR(100),
    min_capacity INT DEFAULT 0,
    max_capacity INT DEFAULT 0,

    -- duration is needed for 1:1 sessions
    duration_unit VARCHAR(50),
    duration_quantity INT DEFAULT 0,
    
    total_orders INT DEFAULT 0,
    total_revenue BIGINT DEFAULT 0, -- total de facturacion de un producto en céntimos

    total_resources INT DEFAULT 0,
    total_duration INT DEFAULT 0,   
    total_size BIGINT DEFAULT 0,  
    total_sections INT DEFAULT 0,
    availability_type VARCHAR(50),

    location_cache JSONB,
    gallery_cache JSONB,
    banner_cache JSONB,
    featured_media_cache JSONB,
    faqs_cache JSONB,
    testimonials_cache JSONB,
    post_booking_steps_cache JSONB,
    booking_settings_cache JSONB,
    template_cache JSONB,
    weekly_availability_cache JSONB,
    installment_program_cache JSONB,
    description_section_cache JSONB,
    terms_and_conditions_cache JSONB,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    migrated_at TIMESTAMPTZ,

    UNIQUE(host_id, alias)
);

CREATE TABLE app_core.product_plan (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  -- temporal
  migration_id VARCHAR(255),
  checkout_id VARCHAR(255) NOT NULL UNIQUE DEFAULT substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
  product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
  discount_id BIGINT REFERENCES app_core.discount(id) ON DELETE SET NULL,

  name VARCHAR(255) NOT NULL,
  description TEXT,
  order_index INT NOT NULL,
  price BIGINT,                          -- precio base en céntimos
  
  
  max_capacity INT,                      -- cupos máximos
  total_orders INT DEFAULT 0,          -- total de reservas permitidas
  currency VARCHAR(10) DEFAULT 'USD',
  pricing_model VARCHAR(50) NOT NULL,     -- 'ONE_TIME', 'RECURRING', 'FREE', 'PAY_WHAT_YOU_WANT'
  payment_interval INT,                  -- dias entre pagos (si es recurrente) -- 30, 60, 90, 180, 360, custom
  free_trial_period INT,                 -- dias de prueba gratis -- 7, 14, 30, 60, 90, 180, 360, custom
  redirect_after_checkout VARCHAR(1000), -- URL de redirección después del pago
  enable_member_count BOOLEAN DEFAULT FALSE,
  auto_expire_access_period INT,          -- dias para expirar el acceso -- 7, 14, 30, 60, 90, 180, 360, custom
  access_quantity INT,                    -- cantidad de accesos permitidos por este plan

  -- Trial and reservation fields
  free_trial_requires_payment BOOLEAN DEFAULT FALSE, -- si el trial requiere pago
  pre_reserve_amount BIGINT,              -- monto de reserva previa en céntimos
  pre_reserve_due_days INT,               -- días para pagar la reserva previa

  -- Condiciones del plan
  only_for_subscribers BOOLEAN DEFAULT FALSE,
  early_bird BOOLEAN DEFAULT FALSE,

  -- Discount fields
  discount_percentage INT,
  discount_valid_from TIMESTAMPTZ,
  discount_valid_until TIMESTAMPTZ,
  discount_max_capacity INT,
  discount_conditions JSONB,

  -- Total 
  total_resources INT DEFAULT 0,
  total_duration INT DEFAULT 0,   
  total_size BIGINT DEFAULT 0,  
  total_sections INT DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  migrated_at TIMESTAMPTZ,
  tags JSONB
);


CREATE TABLE app_core.product_date (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    -- temporal
    migration_id VARCHAR(255),
    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,

    initial_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    timezone VARCHAR(100),

    status app_core.product_date_status NOT NULL DEFAULT 'DEPENDS_ON_DATE',
    total_orders INT DEFAULT 0,
    max_capacity INT DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    migrated_at TIMESTAMPTZ
);


CREATE TABLE app_core.product_discount (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    discount_id BIGINT NOT NULL REFERENCES app_core.discount(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    migrated_at TIMESTAMPTZ,
    UNIQUE(product_id, discount_id)
);



CREATE TABLE app_core.product_multimedia (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    multimedia_id BIGINT NOT NULL REFERENCES app_core.multimedia(id) ON DELETE CASCADE,
    order_index INT,
    usage_type VARCHAR(50), -- 'gallery', 'banner', 'preview'
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE app_core.product_participant (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    -- Producto y dueño principal
    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    owner_host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,  -- Host dueño del producto

    -- Participante (coproductor o colaborador)
    participant_user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,  -- Usuario participante
    participant_host_id BIGINT REFERENCES app_core.host(id) ON DELETE SET NULL,              -- Host público del participante

    -- Tipo y rol del participante
    participant_type VARCHAR(50) NOT NULL, -- 'CO_PRODUCER', 'COLLABORATOR'

    -- Participación económica (en centésimas)
    -- Ejemplo: 25.00% = 2500  |  12.5% = 1250
    revenue_share INT CHECK (revenue_share >= 0 AND revenue_share <= 10000) DEFAULT 0,

    -- Visibilidad pública
    is_public BOOLEAN DEFAULT FALSE,

    -- Vigencia y estado
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    valid_from TIMESTAMPTZ DEFAULT now(),
    valid_until TIMESTAMPTZ,

    -- Control de auditoría
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    UNIQUE (product_id, participant_user_id, participant_type)
);

CREATE TABLE app_core.product_offer (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

  host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
  source_product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
  target_product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
  target_plan_id BIGINT NOT NULL REFERENCES app_core.product_plan(id) ON DELETE CASCADE,


  type VARCHAR(50) NOT NULL,
  stage VARCHAR(50) NOT NULL,
  status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
  discount_percentage INT NOT NULL,

  title VARCHAR(255),
  description TEXT, --cambiado VARCHAR(255),
  cta VARCHAR(100),
  total_orders INT DEFAULT 0,
  total_revenue BIGINT DEFAULT 0, -- total de facturacion de un producto en céntimos

  order_index INT,


  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMPTZ
);


CREATE TABLE app_core.payment_option (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    owner_type VARCHAR(50) NOT NULL, -- 'APP', 'USER', 'HOST'
    user_id BIGINT REFERENCES app_core.app_user(id) ON DELETE CASCADE,

    payment_method_id BIGINT NOT NULL REFERENCES app_core.payment_method(id) ON DELETE RESTRICT,
    custom_attributes JSONB,              -- { "bank": "...", "nationalId": "...", "phoneNumber": {...} }
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.host_payment_option (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    payment_option_id BIGINT NOT NULL REFERENCES app_core.payment_option(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ,
    UNIQUE(host_id, payment_option_id)
);


CREATE TABLE app_core.invoice (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    invoice_number VARCHAR(100),
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    payment_method_id BIGINT NOT NULL REFERENCES app_core.payment_method(id),
    payment_option_id BIGINT REFERENCES app_core.payment_option(id),

    status VARCHAR(50) NOT NULL,
    subtotal BIGINT NOT NULL DEFAULT 0,
    tax_total BIGINT NOT NULL DEFAULT 0,
    discount_total BIGINT NOT NULL DEFAULT 0, 
    total BIGINT NOT NULL,     
    total_converted BIGINT NOT NULL,  
    exchange_rate  NUMERIC(18,6) NOT NULL,
    receipt VARCHAR(1000),

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);


CREATE TABLE app_core.invoice_breakdown (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id BIGINT NOT NULL REFERENCES app_core.invoice(id) ON DELETE CASCADE,
    key VARCHAR(100) NOT NULL,       
    description VARCHAR(300),
    percentage NUMERIC(10,2),
    amount BIGINT NOT NULL,
    order_index INT,
    created_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.invoice_item (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    invoice_id BIGINT NOT NULL REFERENCES app_core.invoice(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, 
    amount BIGINT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    total_amount BIGINT NOT NULL,
    migrated_at TIMESTAMPTZ
);


CREATE TABLE app_core.purchase_order (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key VARCHAR(100),
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    ticket_number VARCHAR(100) NOT NULL UNIQUE,
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    buyer_id BIGINT REFERENCES app_core.app_user(id) ON DELETE CASCADE,
    payment_mode VARCHAR(50) NOT NULL, -- 'UPFRONT', 'INSTALLMENTS'
    payment_status VARCHAR(50), -- 'PENDING', 'CONFIRMED', 'CONFIRMATION_PENDING'
    timezone VARCHAR(100),
    is_test BOOLEAN DEFAULT FALSE,
    free_access BOOLEAN DEFAULT FALSE,
    access_type VARCHAR(50), -- 'FREE_ACCESS', 'RESOURCES_ACCESS'
    installments_program_applied BOOLEAN DEFAULT FALSE,
    commission_payer VARCHAR(50), -- 'HOST', 'CUSTOMER'

    -- Totales
    subtotal INT,
    discount INT, 
    installment_fee INT,
    platform_fee INT,
    taxes_fee INT,
    total INT,
    commissionable_amount INT, -- amount on which the platform commission is calculated
    net_revenue INT, -- creator revenue after platform commission

    installments_count INT DEFAULT 0, -- cantidad de cuotas/pagos

    -- Cancellation fields
    cancellation_reason_key VARCHAR(100),     -- reason key for cancellation
    cancellation_reason_description VARCHAR(500), -- detailed description of cancellation reason

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.purchase_order_breakdown (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purchase_order_id BIGINT NOT NULL REFERENCES app_core.purchase_order(id) ON DELETE CASCADE,
    purchase_order_item_id BIGINT,
    discount_id BIGINT REFERENCES app_core.discount(id) ON DELETE SET NULL,
    category VARCHAR(50) NOT NULL,
    key VARCHAR(50) NOT NULL,
    percentage INT,
    amount INT NOT NULL,
    order_index INT,
    discount_snapshot JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);


CREATE TABLE app_core.purchase_order_platform_fee (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purchase_order_id BIGINT NOT NULL REFERENCES app_core.purchase_order(id) ON DELETE CASCADE,
    purchase_order_item_id BIGINT,
    percentage INT,
    key VARCHAR(50) NOT NULL,
    amount INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.purchase_order_item (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    purchase_order_id BIGINT NOT NULL REFERENCES app_core.purchase_order(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    plan_id BIGINT REFERENCES app_core.product_plan(id) ON DELETE SET NULL,
    date_id BIGINT REFERENCES app_core.product_date(id) ON DELETE SET NULL,

    session_start_date  TIMESTAMPTZ,
    session_end_date  TIMESTAMPTZ,
    pricing_model VARCHAR(50) NOT NULL,
    main_item BOOLEAN,

    quantity INT NOT NULL DEFAULT 1,
    base_price BIGINT NOT NULL,                 -- precio base en céntimos
    plan_discount_amount BIGINT NOT NULL,
    offer_discount_amount BIGINT,
    total_discount_amount BIGINT,
    final_unit_price BIGINT NOT NULL,
    subtotal BIGINT NOT NULL,
    coupon_discount INT,
    commissionable_amount INT,
    coupon_id BIGINT REFERENCES app_core.discount(id) ON DELETE SET NULL,

    platform_fee INT, -- variable fee amount 
    allocation_ratio  NUMERIC(10,6), -- Represents the proportional share of this item within the total order value, used to accurately allocate payments amounts
  
    item_snapshot JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    migrated_at TIMESTAMPTZ
);

-- Add FK constraints after purchase_order_item is created
ALTER TABLE app_core.purchase_order_breakdown
    ADD CONSTRAINT purchase_order_breakdown_item_fk
    FOREIGN KEY (purchase_order_item_id) REFERENCES app_core.purchase_order_item(id) ON DELETE CASCADE;

ALTER TABLE app_core.purchase_order_platform_fee
    ADD CONSTRAINT purchase_order_platform_fee_item_fk
    FOREIGN KEY (purchase_order_item_id) REFERENCES app_core.purchase_order_item(id) ON DELETE CASCADE;

CREATE TABLE app_core.attendee (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    purchase_order_id BIGINT NOT NULL REFERENCES app_core.purchase_order(id) ON DELETE CASCADE,
    user_id BIGINT REFERENCES app_core.app_user(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE app_core.payment (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    payment_number VARCHAR(100) NOT NULL UNIQUE,

    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,
    purchase_order_id BIGINT NOT NULL REFERENCES app_core.purchase_order(id) ON DELETE CASCADE,

    payment_option_id BIGINT REFERENCES app_core.payment_option(id) ON DELETE SET NULL,
    payment_method_id BIGINT NOT NULL REFERENCES app_core.payment_method(id),
    payment_status VARCHAR(50),
    receipt VARCHAR(1000),  
    reference_code VARCHAR(100),
    pre_save BOOLEAN DEFAULT FALSE,
    subtotal  INT NOT NULL,
    net_subtotal INT NOT NULL,
    net_revenue INT NOT NULL,
    gateway_fee INT,
    platform_fee INT,
    installments_fee INT,
    total INT NOT NULL,
    exchange_rate NUMERIC(18,6),           -- tasa de cambio
    total_converted INT,                -- total convertido en céntimos (ej: en céntimos VES)

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.payment_purchase_order_item (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_id BIGINT NOT NULL REFERENCES app_core.payment(id) ON DELETE CASCADE,
    purchase_order_item_id BIGINT NOT NULL REFERENCES app_core.purchase_order_item(id) ON DELETE CASCADE,
    allocation_ratio NUMERIC(10,6) NOT NULL,
    amount INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.payment_split (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    payment_id BIGINT NOT NULL REFERENCES app_core.payment(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES app_core.product(id) ON DELETE SET NULL,

    beneficiary_type VARCHAR(50) NOT NULL,
    beneficiary_user_id BIGINT REFERENCES app_core.app_user(id) ON DELETE SET NULL,
    purchase_order_item_id BIGINT REFERENCES app_core.purchase_order_item(id) ON DELETE CASCADE,
    base_amount INT,
    percentage INT,
    amount INT NOT NULL,
    amount_converted INT,
    due_date DATE,
    grace_period_end_date DATE,
    paid_at TIMESTAMPTZ,
    is_overdue BOOLEAN DEFAULT FALSE,
    status VARCHAR(50) NOT NULL,
    invoice_id BIGINT REFERENCES app_core.invoice(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.payment_split_item (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_split_id BIGINT NOT NULL 
        REFERENCES app_core.payment_split(id) ON DELETE CASCADE,
    key VARCHAR(100),              
    amount INT,           -- monto absoluto aplicado al split
    amount_converted INT, -- monto convertido en la moneda de la transacción
    percentage INT,       -- porcentaje aplicado (si aplica)
    
    created_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.installment (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    migration_id VARCHAR(255),
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    purchase_order_id BIGINT NOT NULL REFERENCES app_core.purchase_order(id) ON DELETE CASCADE,
    
    installment_number INT NOT NULL,
    amount BIGINT NOT NULL,                -- monto en céntimos
    platform_fee INT,
    installments_fee INT,
    due_date TIMESTAMPTZ NOT NULL,
    payment_id BIGINT REFERENCES app_core.payment(id) ON DELETE SET NULL,
    notifications_sent INT,
    last_notification_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.referral_code (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    referrer_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE, -- el que invita
    code VARCHAR(50) NOT NULL UNIQUE,  -- el código de referido

    referral_rate DECIMAL(5,2) NOT NULL CHECK (referral_rate >= 1 AND referral_rate <= 100), -- % comisión
    duration_days INT,     -- duración de la relación (ej: 90 días)
    cap_minor BIGINT,      -- límite máximo de comisiones acumuladas en céntimos
    window_days INT,       -- tiempo en días en que se puede activar la comisión

    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE app_core.referral_association (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    referred_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE, 

    utm_source VARCHAR(255),
    referral_code_id BIGINT REFERENCES app_core.referral_code(id) ON DELETE CASCADE, 

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(referred_id, referral_code_id)
);


CREATE TABLE app_core.temporal_token (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    user_id BIGINT REFERENCES app_core.app_user(id) ON DELETE CASCADE,

    token_type VARCHAR(50) NOT NULL,        -- 'COMPLETE_REGISTRATION', 'LOGIN_REDIRECT', 'PASSWORD_RESET'
    redirect_url VARCHAR(1000),

    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    retries INT DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),


    UNIQUE(user_id, token_type)
);


CREATE TABLE app_core.confirmation_code (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL,               -- código corto (ej: 6 dígitos o string aleatorio)
    code_type VARCHAR(50) NOT NULL,          -- 'EMAIL_VERIFICATION', 'LOGIN', 'TWO_FACTOR', etc.
    used BOOLEAN DEFAULT FALSE,
    ttl INT NOT NULL,          
    redirect_type VARCHAR(50),   --     ADMIN_REDIRECT or CLIENT_REDIRECT     
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(user_id, code_type)
);


CREATE TABLE app_core.user_access (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    plan_id BIGINT REFERENCES app_core.product_plan(id) ON DELETE CASCADE,
    date_id BIGINT REFERENCES app_core.product_date(id) ON DELETE CASCADE,

    session_start_date TIMESTAMPTZ,
    session_end_date TIMESTAMPTZ,

    purchase_order_item_id BIGINT REFERENCES app_core.purchase_order_item(id) ON DELETE CASCADE,
    purchase_order_id BIGINT REFERENCES app_core.purchase_order(id) ON DELETE CASCADE,

    -- Estado de acceso independiente a la compra
    status app_core.user_access_status NOT NULL DEFAULT 'CONFIRMATION_PENDING', 

    -- Fechas de vigencia
    access_start TIMESTAMPTZ DEFAULT now(),
    access_end TIMESTAMPTZ,

    revoked_reason TEXT,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    migrated_at TIMESTAMPTZ
);




CREATE TABLE app_core.resource (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    host_id BIGINT NOT NULL REFERENCES app_core.host(id) ON DELETE CASCADE,

    parent_id BIGINT REFERENCES app_core.resource(id) ON DELETE CASCADE, -- para jerarquía (secciones → lecciones → recursos)
    
    path LTREE,
    type VARCHAR(50) NOT NULL,         -- 'SECTION', 'RESOURCE', 'QUIZ', 'SURVEY'
    file_type VARCHAR(100),            -- 'VIDEO', 'DOCUMENT', 'IMAGE', 'AUDIO', 'TEXT', 'URL' , OTHER
    filename VARCHAR(500),

    title VARCHAR(255) NOT NULL,
    description TEXT,
    long_description TEXT,
    duration DECIMAL(10,2),
    size BIGINT,          
    url varchar(2048),
    source VARCHAR(50), -- 'APP', 'LINK', 'YOUTUBE', 'GOOGLE_DRIVE', 'BUNNY_STORAGE', 'BUNNY_STREAM'

    file_id VARCHAR(255),              -- id en storage externo
    processing_status VARCHAR(50),   -- 'TRANSCODING', 'READY'
    encode_progress INT,
    thumbnail JSONB,
    preview BOOLEAN DEFAULT FALSE,
    downloadable BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);

CREATE TABLE app_core.product_resource_relation (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    resource_id BIGINT NOT NULL REFERENCES app_core.resource(id) ON DELETE CASCADE,
    order_index SMALLINT NOT NULL,
    total_views INT DEFAULT 0,
    restricted BOOLEAN DEFAULT FALSE,
    status app_core.common_status NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);


CREATE TABLE app_core.product_resource_plan (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    product_resource_relation_id BIGINT NOT NULL REFERENCES app_core.product_resource_relation(id) ON DELETE CASCADE, 
    resource_id BIGINT NOT NULL REFERENCES app_core.resource(id) ON DELETE CASCADE, 
    product_plan_id BIGINT NOT NULL REFERENCES app_core.product_plan(id) ON DELETE CASCADE,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),

    UNIQUE(product_resource_relation_id, product_plan_id)
);

CREATE TABLE app_core.question (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    resource_id BIGINT NOT NULL REFERENCES app_core.resource(id) ON DELETE CASCADE, -- CAMBIAR EN BD URGENTE

    text TEXT NOT NULL,
    question_type VARCHAR(50) NOT NULL,   -- 'MULTIPLE_CHOICE_SINGLE', 'MULTIPLE_CHOICE_MULTIPLE', 'TRUE_FALSE', 'OPEN_TEXT', 'RATING'
    order_index INT NOT NULL,
    points INT,

    explanation TEXT,          -- explicación de la respuesta correcta (opcional)
    rating_scale INT,          -- escala para rating (ej: 1-5)
    min_rating_label VARCHAR(255),
    max_rating_label VARCHAR(255),
    is_required BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ
);


CREATE TABLE app_core.answer_option (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    question_id BIGINT NOT NULL REFERENCES app_core.question(id) ON DELETE CASCADE,

    text TEXT NOT NULL,
    order_index INT,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);


CREATE TABLE app_core.user_answer (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,

    -- We save product_id instead of product_resource_relation to keep history of the progress, even if the relation between product and resource is deleted
    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    question_id BIGINT NOT NULL REFERENCES app_core.question(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,

    -- tipos de respuestas posibles
    answer_text TEXT, 
    rating_value INT,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ,

    UNIQUE(question_id, product_id, user_id)
);


CREATE TABLE app_core.user_answer_option (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    user_answer_id BIGINT NOT NULL REFERENCES app_core.user_answer(id) ON DELETE CASCADE,
    answer_option_id BIGINT NOT NULL REFERENCES app_core.answer_option(id) ON DELETE CASCADE,
    UNIQUE(user_answer_id, answer_option_id)
);

CREATE TABLE app_core.user_product_progress (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
  access_id BIGINT REFERENCES app_core.user_access(id) ON DELETE CASCADE,

  last_accessed_at TIMESTAMPTZ DEFAULT now(),
  last_accessed_resource_id BIGINT REFERENCES app_core.resource(id) ON DELETE SET NULL,
  last_accessed_resource_seconds INT DEFAULT 0,
  progress_percent DECIMAL(5,2) DEFAULT 0.00,
  completed_resources INT DEFAULT 0,
  completed_at TIMESTAMPTZ,
  migrated_at TIMESTAMPTZ,

  UNIQUE(user_id, product_id, access_id)
);

CREATE UNIQUE INDEX user_prog_uniq
ON app_core.user_product_progress (user_id, product_id)
WHERE access_id IS NULL;

CREATE TABLE app_core.user_resource_progress (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    user_id BIGINT NOT NULL REFERENCES app_core.app_user(id) ON DELETE CASCADE,

    product_id BIGINT NOT NULL REFERENCES app_core.product(id) ON DELETE CASCADE,
    resource_id BIGINT NOT NULL REFERENCES app_core.resource(id) ON DELETE CASCADE,
    access_id BIGINT REFERENCES app_core.user_access(id) ON DELETE CASCADE,

    -- Estado actual del progreso
    status VARCHAR(50) NOT NULL DEFAULT 'IN_PROGRESS', 
    progress_percent DECIMAL(5,2) DEFAULT 0.00, -- % completado (ej: 75.50)
    completed_at TIMESTAMPTZ,                   -- fecha de finalización (si aplica)
    last_accessed_at TIMESTAMPTZ DEFAULT now(), -- última vez que lo vio
    last_second INT DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ,

    UNIQUE(user_id, product_id, resource_id, access_id)
);

-- Unique index for user_resource_progress when access_id is NULL to prevent duplicates
CREATE UNIQUE INDEX user_res_prog_uniq
ON app_core.user_resource_progress (user_id, product_id, resource_id)
WHERE access_id IS NULL;

CREATE TABLE app_core.kyc_session (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    user_id BIGINT REFERENCES app_core.app_user(id) ON DELETE CASCADE,
    session_id UUID NOT NULL,               -- ID de sesión en el proveedor externo
    metadata JSONB,                         -- datos adicionales dinámicos (userType, accountId, etc.)
    status app_core.kyc_session_status NOT NULL DEFAULT 'NOT_STARTED',

    url VARCHAR(1000) NOT NULL,-- URL para redirigir al usuario al vendor KYC
    retries INT default 0, 
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    warnings JSONB,
    migrated_at TIMESTAMPTZ,
    
    UNIQUE(user_id)
);

CREATE TABLE app_core.kyc_identity (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    record_id UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    session_number INT,
    user_id BIGINT REFERENCES app_core.app_user(id) ON DELETE CASCADE,
 
    -- Persona natural / jurídica
    person_type VARCHAR(50) NOT NULL DEFAULT 'NATURAL',    -- NATURAL, LEGAL_ENTITY (empresa), COMPANY, etc.

    -- Datos básicos
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    full_name VARCHAR(500),
    gender VARCHAR(20),
    age INT,
    date_of_birth DATE,
    marital_status VARCHAR(50),
    nationality VARCHAR(100),
    place_of_birth VARCHAR(255),

    -- Documento
    document_number VARCHAR(100),
    document_type VARCHAR(100),      -- cédula, pasaporte, rif, etc.
    issuing_state VARCHAR(10),       -- ej: VEN
    issuing_state_name VARCHAR(255), -- ej: Venezuela
    date_of_issue DATE,
    expiration_date DATE,

    -- Archivos multimedia asociados
    portrait_image TEXT,       -- selfie o retrato
    front_image TEXT,
    back_image TEXT,
    front_video TEXT,
    back_video TEXT,
    full_front_image TEXT,
    full_back_image TEXT,

    -- Dirección
    address TEXT,
    formatted_address TEXT,
    parsed_address TEXT,

    -- Extra
    extra_fields JSONB,  -- valores dinámicos
    extra_files JSONB,   -- links u objetos

    session_id UUID,     -- vinculado a sesión de KYC

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    migrated_at TIMESTAMPTZ,

    UNIQUE(user_id )
);

-- ================================================
-- ENABLE ROW LEVEL SECURITY para todas las tablas
-- ================================================

ALTER TABLE app_core.status ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.category ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.meeting_platform ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.currency ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.role ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.payment_method ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.payment_fee_rule ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.discount ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.billing_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.plan_breakdown ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.host_billing_plan_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.host ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.app_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.multimedia ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.host_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.customer_tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.customer_tag_relation ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.host_social_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.host_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.host_billing_discount ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_date ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_discount ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_multimedia ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_participant ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_offer ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.payment_option ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.host_payment_option ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.invoice ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.invoice_breakdown ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.invoice_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.attendee ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.payment_purchase_order_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.payment_split ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.payment_split_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.installment ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.purchase_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.purchase_order_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.purchase_order_breakdown ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.purchase_order_platform_fee ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.referral_code ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.referral_association ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.temporal_token ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.confirmation_code ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.resource ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_resource_relation ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.product_resource_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.question ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.answer_option ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_answer ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_answer_option ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_resource_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.user_product_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.kyc_session ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_core.kyc_identity ENABLE ROW LEVEL SECURITY;

-- ================================================
  -- Trigger para actualizar el flag verified_kyc del usuario
  -- Actualiza: app_user
-- ================================================
CREATE OR REPLACE FUNCTION app_core.update_user_verified_kyc()
RETURNS TRIGGER AS $$
BEGIN
  -- Para INSERT y UPDATE: marcar TRUE si existe al menos un registro de identidad para el usuario
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE app_core.app_user
    SET verified_kyc = TRUE
    WHERE id = NEW.user_id;
    RETURN NEW;
  END IF;

  -- Para DELETE: verificar si aún quedan registros KYC asociados
  IF TG_OP = 'DELETE' THEN
    UPDATE app_core.app_user
    SET verified_kyc = EXISTS (
      SELECT 1 FROM app_core.kyc_identity WHERE user_id = OLD.user_id
    )
    WHERE id = OLD.user_id;
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;



CREATE TRIGGER trg_update_user_verified_kyc
AFTER INSERT OR UPDATE OR DELETE
ON app_core.kyc_identity
FOR EACH ROW
EXECUTE FUNCTION app_core.update_user_verified_kyc();

-- ================================================
-- Trigger para setear el path del resource
-- ================================================

CREATE OR REPLACE FUNCTION app_core.set_resource_path()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.parent_id IS NULL THEN
    NEW.path := text2ltree(NEW.id::text);
  ELSE
    NEW.path := (
      SELECT path || text2ltree(NEW.id::text)
      FROM app_core.resource
      WHERE id = NEW.parent_id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_path ON app_core.resource;

CREATE TRIGGER trg_set_path
BEFORE INSERT OR UPDATE OF parent_id ON app_core.resource
FOR EACH ROW
EXECUTE FUNCTION app_core.set_resource_path();


-- ================================================
-- Trigger para actualizar el flag restricted del product_resource
-- ================================================

CREATE OR REPLACE FUNCTION app_core.update_relation_restricted_flag()
RETURNS TRIGGER AS $$
DECLARE
  v_relation_id BIGINT;
  v_has_plans BOOLEAN;
BEGIN
  -- Determinar el product_resource_relation_id según operación
  IF TG_OP = 'DELETE' THEN
    v_relation_id := OLD.product_resource_relation_id;
  ELSE
    v_relation_id := NEW.product_resource_relation_id;
  END IF;

  -- Verificar si existen planes asociados
  SELECT EXISTS (
    SELECT 1
    FROM app_core.product_resource_plan
    WHERE product_resource_relation_id = v_relation_id
  ) INTO v_has_plans;

  -- Actualizar el campo restricted en product_resource_relation
  UPDATE app_core.product_resource_relation
  SET restricted = v_has_plans
  WHERE id = v_relation_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trg_update_relation_restricted_flag ON app_core.product_resource_plan;

CREATE TRIGGER trg_update_relation_restricted_flag
AFTER INSERT OR DELETE ON app_core.product_resource_plan
FOR EACH ROW
EXECUTE FUNCTION app_core.update_relation_restricted_flag();




-- ================================================
-- Trigger para actualizar los totales del producto relacionado con el product_resources
-- ================================================

CREATE OR REPLACE FUNCTION app_core.update_product_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_product_id BIGINT;
  v_relation_id BIGINT;
BEGIN
  -- Determine product_id depending on the source table and operation
  IF TG_TABLE_NAME = 'product_resource_relation' THEN
    IF TG_OP = 'DELETE' THEN
      v_product_id := OLD.product_id;
    ELSE
      v_product_id := NEW.product_id;
    END IF;
  ELSIF TG_TABLE_NAME = 'product_resource_plan' THEN
    IF TG_OP = 'DELETE' THEN
      v_relation_id := OLD.product_resource_relation_id;
    ELSE
      v_relation_id := NEW.product_resource_relation_id;
    END IF;

    SELECT prr.product_id
    INTO v_product_id
    FROM app_core.product_resource_relation prr
    WHERE prr.id = v_relation_id;
  ELSE
    RETURN NULL;
  END IF;

  IF v_product_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Update product totals (all resources of the product) only when source table is product_resource_relation
  IF TG_TABLE_NAME = 'product_resource_relation' THEN
    UPDATE app_core.product
    SET
      total_resources = (
        SELECT COUNT(*)
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
          AND r.type <> 'SECTION'
      ),

      total_duration = (
        SELECT COALESCE(SUM(r.duration), 0)::INT
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
      ),

      total_size = (
        SELECT COALESCE(SUM(r.size), 0)
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
      ),

      total_sections = (
        SELECT COUNT(*)
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
          AND r.type = 'SECTION'
      )
    WHERE id = v_product_id;
  END IF;

  -- Reset product_plan totals for this product
  UPDATE app_core.product_plan pp
  SET
    total_resources = 0,
    total_duration = 0,
    total_size = 0,
    total_sections = 0
  WHERE pp.product_id = v_product_id;

  -- Update product_plan totals, considering restricted flag and plan relations
  UPDATE app_core.product_plan pp
  SET
    total_resources = sub.total_resources,
    total_duration = sub.total_duration,
    total_size = sub.total_size,
    total_sections = sub.total_sections
  FROM (
    SELECT
      pp2.id AS plan_id,
      COUNT(*) FILTER (
        WHERE r.type <> 'SECTION'
      ) AS total_resources,
      COALESCE(SUM(r.duration), 0)::INT AS total_duration,
      COALESCE(SUM(r.size), 0) AS total_size,
      COUNT(*) FILTER (
        WHERE r.type = 'SECTION'
      ) AS total_sections
    FROM app_core.product_plan pp2
    JOIN app_core.product_resource_relation prr
      ON prr.product_id = pp2.product_id
    JOIN app_core.resource r
      ON r.id = prr.resource_id
    WHERE pp2.product_id = v_product_id
      AND (
        prr.restricted = FALSE
        OR (
          prr.restricted = TRUE
          AND EXISTS (
            SELECT 1
            FROM app_core.product_resource_plan prp
            WHERE prp.product_resource_relation_id = prr.id
              AND prp.product_plan_id = pp2.id
          )
        )
      )
    GROUP BY pp2.id
  ) AS sub
  WHERE pp.id = sub.plan_id
    AND pp.product_id = v_product_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_product_totals ON app_core.product_resource_relation;

CREATE TRIGGER trg_update_product_totals
AFTER INSERT OR UPDATE OR DELETE ON app_core.product_resource_relation
FOR EACH ROW
EXECUTE FUNCTION app_core.update_product_totals();

DROP TRIGGER IF EXISTS trg_update_product_totals_on_plan ON app_core.product_resource_plan;

CREATE TRIGGER trg_update_product_totals_on_plan
AFTER INSERT OR UPDATE OR DELETE ON app_core.product_resource_plan
FOR EACH ROW
EXECUTE FUNCTION app_core.update_product_totals();


CREATE OR REPLACE FUNCTION app_core.update_product_totals_on_resource_update()
RETURNS TRIGGER AS $$
DECLARE
  v_product_id BIGINT;
BEGIN
  -- Exit if columns that affect totals are not changed.
  IF OLD.duration IS NOT DISTINCT FROM NEW.duration
    AND OLD.size IS NOT DISTINCT FROM NEW.size
    AND OLD.type IS NOT DISTINCT FROM NEW.type
  THEN
    RETURN NULL;
  END IF;

  -- Loop through all products associated with the updated resource
  FOR v_product_id IN
    SELECT product_id
    FROM app_core.product_resource_relation
    WHERE resource_id = NEW.id
  LOOP
    -- Update product totals
    UPDATE app_core.product
    SET
      total_resources = (
        SELECT COUNT(*)
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
          AND r.type <> 'SECTION'
      ),
      total_duration = (
        SELECT COALESCE(SUM(r.duration), 0)::INT
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
      ),
      total_size = (
        SELECT COALESCE(SUM(r.size), 0)
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
      ),
      total_sections = (
        SELECT COUNT(*)
        FROM app_core.product_resource_relation prr
        JOIN app_core.resource r ON r.id = prr.resource_id
        WHERE prr.product_id = v_product_id
          AND r.type = 'SECTION'
      )
    WHERE id = v_product_id;

    -- Reset product_plan totals for this product
    UPDATE app_core.product_plan pp
    SET
      total_resources = 0,
      total_duration = 0,
      total_size = 0,
      total_sections = 0
    WHERE pp.product_id = v_product_id;

    -- Update product_plan totals, considering restricted flag and plan relations
    UPDATE app_core.product_plan pp
    SET
      total_resources = sub.total_resources,
      total_duration = sub.total_duration,
      total_size = sub.total_size,
      total_sections = sub.total_sections
    FROM (
      SELECT
        pp2.id AS plan_id,
        COUNT(*) FILTER (
          WHERE r.type <> 'SECTION'
        ) AS total_resources,
        COALESCE(SUM(r.duration), 0)::INT AS total_duration,
        COALESCE(SUM(r.size), 0) AS total_size,
        COUNT(*) FILTER (
          WHERE r.type = 'SECTION'
        ) AS total_sections
      FROM app_core.product_plan pp2
      JOIN app_core.product_resource_relation prr
        ON prr.product_id = pp2.product_id
      JOIN app_core.resource r
        ON r.id = prr.resource_id
      WHERE pp2.product_id = v_product_id
        AND (
          prr.restricted = FALSE
          OR (
            prr.restricted = TRUE
            AND EXISTS (
              SELECT 1
              FROM app_core.product_resource_plan prp
              WHERE prp.product_resource_relation_id = prr.id
                AND prp.product_plan_id = pp2.id
            )
          )
        )
      GROUP BY pp2.id
    ) AS sub
    WHERE pp.id = sub.plan_id
      AND pp.product_id = v_product_id;
  END LOOP;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_product_totals_on_resource_update ON app_core.resource;

CREATE TRIGGER trg_update_product_totals_on_resource_update
AFTER UPDATE ON app_core.resource
FOR EACH ROW
EXECUTE FUNCTION app_core.update_product_totals_on_resource_update();



-- ================================================
-- Trigger para actualizar el progreso del usuario relacionado con el user_product_progress
-- Actualiza: user_product_progress
-- ================================================



CREATE OR REPLACE FUNCTION app_core.refresh_user_product_progress()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id BIGINT;
  v_product_id BIGINT;
  v_access_id BIGINT;
  v_plan_id BIGINT;

  v_completed_resources INT;
  v_total_resources INT;

  v_progress DECIMAL(5,2);
  v_completed_at TIMESTAMPTZ;

  v_last_resource_id BIGINT;
  v_last_resource_seconds INT;
  v_last_accessed_at TIMESTAMPTZ;

  v_user_has_progress_records INT;
BEGIN
  -- Get user, product and access from the trigger
  v_user_id := COALESCE(NEW.user_id, OLD.user_id);
  v_product_id := COALESCE(NEW.product_id, OLD.product_id);
  v_access_id := COALESCE(NEW.access_id, OLD.access_id);

  -- Get plan_id: only needed when access_id exists (for purchased products)
  -- Academia (access_id IS NULL) counts all resources, so plan_id is not needed
  IF v_access_id IS NOT NULL THEN
    SELECT plan_id, product_id
    INTO v_plan_id, v_product_id
    FROM app_core.user_access
    WHERE id = v_access_id;
  END IF;

  -- Determine last accessed resource
  IF TG_OP = 'DELETE' THEN
    SELECT resource_id, last_second, last_accessed_at
    INTO v_last_resource_id, v_last_resource_seconds, v_last_accessed_at
    FROM app_core.user_resource_progress
    WHERE user_id = v_user_id 
      AND product_id = v_product_id
      AND (v_access_id IS NULL AND access_id IS NULL OR access_id = v_access_id)
    ORDER BY last_accessed_at DESC NULLS LAST
    LIMIT 1;
  ELSE
    v_last_resource_id := NEW.resource_id;
    v_last_resource_seconds := COALESCE(NEW.last_second, 0);
    v_last_accessed_at := COALESCE(NEW.last_accessed_at, now());
  END IF;

  -- Check if user has progress records for this access/product
  IF v_access_id IS NOT NULL THEN
    SELECT COUNT(*)
    INTO v_user_has_progress_records
    FROM app_core.user_resource_progress
    WHERE access_id = v_access_id;
  ELSE
    -- Academia case: check by user_id and product_id (no plan filtering)
    SELECT COUNT(*)
    INTO v_user_has_progress_records
    FROM app_core.user_resource_progress
    WHERE user_id = v_user_id 
      AND product_id = v_product_id
      AND access_id IS NULL;
  END IF;

  -- If no progress, delete the aggregated row
  IF v_user_has_progress_records = 0 THEN
    IF v_access_id IS NOT NULL THEN
      DELETE FROM app_core.user_product_progress
      WHERE user_id = v_user_id AND product_id = v_product_id AND access_id = v_access_id;
    ELSE
      DELETE FROM app_core.user_product_progress
      WHERE user_id = v_user_id AND product_id = v_product_id AND access_id IS NULL;
    END IF;
    RETURN NULL;
  END IF;

  -- Count total resources (not sections)
  -- Academia (access_id IS NULL): count all resources of the product
  -- Purchased products (access_id IS NOT NULL): count only resources available to the plan
  IF v_access_id IS NULL THEN
    -- Academia: all resources of the product
    SELECT COUNT(*)
    INTO v_total_resources
    FROM app_core.product_resource_relation prr
    JOIN app_core.resource r ON r.id = prr.resource_id
    WHERE prr.product_id = v_product_id
      AND r.type <> 'SECTION';
  ELSE
    -- Purchased products: resources available to the plan
    -- Resources count if:
    --   - restricted = FALSE (available to all plans)
    --   - restricted = TRUE AND there's a product_resource_plan entry for this plan_id
    SELECT COUNT(DISTINCT prr.id)
    INTO v_total_resources
    FROM app_core.product_resource_relation prr
    JOIN app_core.resource r ON r.id = prr.resource_id
    WHERE prr.product_id = v_product_id
      AND r.type <> 'SECTION'
      AND (
        prr.restricted = FALSE
        OR (prr.restricted = TRUE AND v_plan_id IS NOT NULL AND EXISTS (
          SELECT 1
          FROM app_core.product_resource_plan prp
          WHERE prp.product_resource_relation_id = prr.id
            AND prp.product_plan_id = v_plan_id
        ))
      );
  END IF;

  -- Count completed resources for this access/user/product
  IF v_access_id IS NOT NULL THEN
    -- Purchased products: count by access_id
    SELECT COUNT(*)
    INTO v_completed_resources
    FROM app_core.user_resource_progress urp
    JOIN app_core.resource r ON r.id = urp.resource_id
    WHERE urp.access_id = v_access_id
      AND urp.status = 'COMPLETED'
      AND r.type <> 'SECTION';
  ELSE
    -- Academia: count by user_id and product_id (all resources, no plan filtering)
    SELECT COUNT(*)
    INTO v_completed_resources
    FROM app_core.user_resource_progress urp
    JOIN app_core.resource r ON r.id = urp.resource_id
    WHERE urp.user_id = v_user_id
      AND urp.product_id = v_product_id
      AND urp.access_id IS NULL
      AND urp.status = 'COMPLETED'
      AND r.type <> 'SECTION';
  END IF;

  -- Calculate progress percentage
  IF v_total_resources > 0 THEN
    v_progress := ROUND((100.0 * v_completed_resources) / v_total_resources, 2);
  ELSE
    v_progress := 0;
  END IF;

  -- Determine completion date
  IF v_completed_resources = v_total_resources AND v_total_resources > 0 THEN
    v_completed_at := now();
  ELSE
    v_completed_at := NULL;
  END IF;

  -- Insert or update aggregated product progress
  -- Handle NULL access_id correctly to avoid duplicates
  IF v_access_id IS NULL THEN
    -- Academia case: check if record exists with NULL access_id
    IF EXISTS (
      SELECT 1
      FROM app_core.user_product_progress
      WHERE user_id = v_user_id
        AND product_id = v_product_id
        AND access_id IS NULL
    ) THEN
      -- Update existing record
      UPDATE app_core.user_product_progress
      SET
        progress_percent = v_progress,
        completed_resources = v_completed_resources,
        completed_at = v_completed_at,
        last_accessed_resource_id = v_last_resource_id,
        last_accessed_resource_seconds = COALESCE(v_last_resource_seconds, 0),
        last_accessed_at = COALESCE(v_last_accessed_at, now())
      WHERE user_id = v_user_id
        AND product_id = v_product_id
        AND access_id IS NULL;
    ELSE
      -- Insert new record
      INSERT INTO app_core.user_product_progress (
        user_id,
        product_id,
        access_id,
        progress_percent,
        completed_resources,
        completed_at,
        last_accessed_resource_id,
        last_accessed_resource_seconds,
        last_accessed_at
      )
      VALUES (
        v_user_id,
        v_product_id,
        NULL,
        v_progress,
        v_completed_resources,
        v_completed_at,
        v_last_resource_id,
        COALESCE(v_last_resource_seconds, 0),
        COALESCE(v_last_accessed_at, now())
      );
    END IF;
  ELSE
    -- Purchased products case: use ON CONFLICT (works fine when access_id is NOT NULL)
    INSERT INTO app_core.user_product_progress (
      user_id,
      product_id,
      access_id,
      progress_percent,
      completed_resources,
      completed_at,
      last_accessed_resource_id,
      last_accessed_resource_seconds,
      last_accessed_at
    )
    VALUES (
      v_user_id,
      v_product_id,
      v_access_id,
      v_progress,
      v_completed_resources,
      v_completed_at,
      v_last_resource_id,
      COALESCE(v_last_resource_seconds, 0),
      COALESCE(v_last_accessed_at, now())
    )
    ON CONFLICT (user_id, product_id, access_id)
    DO UPDATE SET
      progress_percent = EXCLUDED.progress_percent,
      completed_resources = EXCLUDED.completed_resources,
      completed_at = EXCLUDED.completed_at,
      last_accessed_resource_id = EXCLUDED.last_accessed_resource_id,
      last_accessed_resource_seconds = EXCLUDED.last_accessed_resource_seconds,
      last_accessed_at = EXCLUDED.last_accessed_at;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_refresh_user_product_progress ON app_core.user_resource_progress;

CREATE TRIGGER trg_refresh_user_product_progress
AFTER INSERT OR UPDATE OR DELETE
ON app_core.user_resource_progress
FOR EACH ROW
EXECUTE FUNCTION app_core.refresh_user_product_progress();



-- ================================================
-- Trigger to keep purchase_order_item metrics in sync
-- Updates: product (total_orders vía recálculo, total_revenue en insert/reactivación), product_plan, product_date, discount
-- ================================================

CREATE OR REPLACE FUNCTION app_core.update_purchase_order_metrics_on_change()
RETURNS TRIGGER AS $$
DECLARE
  v_product_ids BIGINT[] := ARRAY[
    CASE WHEN TG_OP <> 'DELETE' THEN NEW.product_id END,
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.product_id END,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.product_id END
  ];
  v_plan_ids BIGINT[] := ARRAY[
    CASE WHEN TG_OP <> 'DELETE' THEN NEW.plan_id END,
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.plan_id END,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.plan_id END
  ];
  v_date_ids BIGINT[] := ARRAY[
    CASE WHEN TG_OP <> 'DELETE' THEN NEW.date_id END,
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.date_id END,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.date_id END
  ];
  v_coupon_ids BIGINT[] := ARRAY[
    CASE WHEN TG_OP <> 'DELETE' THEN NEW.coupon_id END,
    CASE WHEN TG_OP = 'UPDATE' THEN OLD.coupon_id END,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.coupon_id END
  ];
  v_id BIGINT;
BEGIN
  -- Recalcular métricas en base a datos actuales (solo órdenes e ítems activos)
  FOR v_id IN (SELECT DISTINCT unnest(v_product_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product p
      SET total_orders = COALESCE(sub.total_orders, 0),
          total_revenue = COALESCE(sub.total_revenue, 0)
      FROM (
        SELECT
          COUNT(poi.id) AS total_orders,
          COALESCE(SUM(CAST(ROUND(po.net_revenue * COALESCE(poi.allocation_ratio, 1)) AS BIGINT)), 0) AS total_revenue
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.product_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE p.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_plan_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product_plan pp
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.plan_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE pp.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_date_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product_date pd
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.date_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE pd.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_coupon_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.discount d
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.coupon_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE d.id = v_id;
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_purchase_order_metrics ON app_core.purchase_order_item;

CREATE TRIGGER trg_update_purchase_order_metrics
AFTER INSERT OR UPDATE OR DELETE ON app_core.purchase_order_item
FOR EACH ROW
EXECUTE FUNCTION app_core.update_purchase_order_metrics_on_change();

-- ================================================
-- Trigger to adjust metrics before deleting purchase_order
-- Ensures revenue and order counters are decremented using item allocation
-- ================================================

CREATE OR REPLACE FUNCTION app_core.update_metrics_before_delete_purchase_order()
RETURNS TRIGGER AS $$
DECLARE
  v_product_ids BIGINT[];
  v_plan_ids BIGINT[];
  v_date_ids BIGINT[];
  v_coupon_ids BIGINT[];
  v_id BIGINT;
BEGIN
  -- Recalculate metrics to post-delete state to avoid drift
  SELECT
    ARRAY_AGG(DISTINCT poi.product_id),
    ARRAY_AGG(DISTINCT poi.plan_id),
    ARRAY_AGG(DISTINCT poi.date_id),
    ARRAY_AGG(DISTINCT poi.coupon_id)
  INTO v_product_ids, v_plan_ids, v_date_ids, v_coupon_ids
  FROM app_core.purchase_order_item poi
  WHERE poi.purchase_order_id = OLD.id;

  IF OLD.buyer_id IS NOT NULL THEN
    UPDATE app_core.customer c
    SET total_orders = COALESCE(sub.total_orders, 0)
    FROM (
      SELECT COUNT(po.id) AS total_orders
      FROM app_core.purchase_order po
      WHERE po.host_id = OLD.host_id
        AND po.buyer_id = OLD.buyer_id
        AND po.deleted_at IS NULL
        AND po.id <> OLD.id
    ) sub
    WHERE c.host_id = OLD.host_id
      AND c.user_id = OLD.buyer_id;
  END IF;

  FOR v_id IN (SELECT DISTINCT unnest(v_product_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product p
      SET total_orders = COALESCE(sub.total_orders, 0),
          total_revenue = COALESCE(sub.total_revenue, 0)
      FROM (
        SELECT
          COUNT(poi.id) AS total_orders,
          COALESCE(SUM(CAST(ROUND(po.net_revenue * COALESCE(poi.allocation_ratio, 1)) AS BIGINT)), 0) AS total_revenue
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.product_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
          AND po.id <> OLD.id
      ) sub
      WHERE p.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_plan_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product_plan pp
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.plan_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
          AND po.id <> OLD.id
      ) sub
      WHERE pp.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_date_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product_date pd
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.date_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
          AND po.id <> OLD.id
      ) sub
      WHERE pd.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_coupon_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.discount d
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.coupon_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
          AND po.id <> OLD.id
      ) sub
      WHERE d.id = v_id;
    END IF;
  END LOOP;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_metrics_before_delete_po ON app_core.purchase_order;

CREATE TRIGGER trg_update_metrics_before_delete_po
BEFORE DELETE ON app_core.purchase_order
FOR EACH ROW
EXECUTE FUNCTION app_core.update_metrics_before_delete_purchase_order();

-- ================================================
-- Trigger to adjust metrics on purchase_order soft delete/reactivate
-- Ensures totals move when deleted_at toggles on the order
-- ================================================

CREATE OR REPLACE FUNCTION app_core.update_metrics_on_purchase_order_soft_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_product_ids BIGINT[];
  v_plan_ids BIGINT[];
  v_date_ids BIGINT[];
  v_coupon_ids BIGINT[];
  v_id BIGINT;
BEGIN
  -- Recalculate metrics to avoid drift when toggling deleted_at
  SELECT
    ARRAY_AGG(DISTINCT poi.product_id),
    ARRAY_AGG(DISTINCT poi.plan_id),
    ARRAY_AGG(DISTINCT poi.date_id),
    ARRAY_AGG(DISTINCT poi.coupon_id)
  INTO v_product_ids, v_plan_ids, v_date_ids, v_coupon_ids
  FROM app_core.purchase_order_item poi
  WHERE poi.purchase_order_id = NEW.id;

  IF NEW.buyer_id IS NOT NULL THEN
    UPDATE app_core.customer c
    SET total_orders = COALESCE(sub.total_orders, 0)
    FROM (
      SELECT COUNT(po.id) AS total_orders
      FROM app_core.purchase_order po
      WHERE po.host_id = NEW.host_id
        AND po.buyer_id = NEW.buyer_id
        AND po.deleted_at IS NULL
    ) sub
    WHERE c.host_id = NEW.host_id
      AND c.user_id = NEW.buyer_id;
  END IF;

  FOR v_id IN (SELECT DISTINCT unnest(v_product_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product p
      SET total_orders = COALESCE(sub.total_orders, 0),
          total_revenue = COALESCE(sub.total_revenue, 0)
      FROM (
        SELECT
          COUNT(poi.id) AS total_orders,
          COALESCE(SUM(CAST(ROUND(po.net_revenue * COALESCE(poi.allocation_ratio, 1)) AS BIGINT)), 0) AS total_revenue
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.product_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE p.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_plan_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product_plan pp
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.plan_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE pp.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_date_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.product_date pd
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.date_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE pd.id = v_id;
    END IF;
  END LOOP;

  FOR v_id IN (SELECT DISTINCT unnest(v_coupon_ids)) LOOP
    IF v_id IS NOT NULL THEN
      UPDATE app_core.discount d
      SET total_orders = COALESCE(sub.total_orders, 0)
      FROM (
        SELECT COUNT(poi.id) AS total_orders
        FROM app_core.purchase_order_item poi
        JOIN app_core.purchase_order po ON po.id = poi.purchase_order_id
        WHERE poi.coupon_id = v_id
          AND poi.deleted_at IS NULL
          AND po.deleted_at IS NULL
      ) sub
      WHERE d.id = v_id;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_metrics_on_po_soft_delete ON app_core.purchase_order;

CREATE TRIGGER trg_update_metrics_on_po_soft_delete
AFTER UPDATE ON app_core.purchase_order
FOR EACH ROW
WHEN (OLD.deleted_at IS DISTINCT FROM NEW.deleted_at)
EXECUTE FUNCTION app_core.update_metrics_on_purchase_order_soft_delete();

-- ================================================
-- Trigger to recalc customer totals on purchase_order insert
-- Updates: customer.total_orders via count to avoid drift
-- ================================================

CREATE OR REPLACE FUNCTION app_core.update_customer_totals_on_po_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.buyer_id IS NOT NULL THEN
    UPDATE app_core.customer c
    SET total_orders = COALESCE(sub.total_orders, 0)
    FROM (
      SELECT COUNT(po.id) AS total_orders
      FROM app_core.purchase_order po
      WHERE po.host_id = NEW.host_id
        AND po.buyer_id = NEW.buyer_id
        AND po.deleted_at IS NULL
    ) sub
    WHERE c.host_id = NEW.host_id
      AND c.user_id = NEW.buyer_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_customer_totals_on_po_insert ON app_core.purchase_order;

CREATE TRIGGER trg_update_customer_totals_on_po_insert
AFTER INSERT ON app_core.purchase_order
FOR EACH ROW
EXECUTE FUNCTION app_core.update_customer_totals_on_po_insert();



CREATE OR REPLACE VIEW app_core.vw_user_access_detailed AS
SELECT
  -- User Access
  ua.id AS user_access_id,
  ua.record_id AS user_access_record_id,
  ua.user_id AS user_id,
  ua.status AS access_status,
  ua.access_start,
  ua.access_end,
  ua.revoked_reason AS access_revoked_reason,
  ua.created_at AS access_created_at,
  ua.updated_at AS access_updated_at,
  ua.deleted_at AS access_deleted_at,
  ua.session_start_date AS access_session_start_date,
  ua.session_end_date AS access_session_end_date,

  -- Purchase Order (reserva global)
  po.id AS purchase_order_id,
  po.record_id AS purchase_order_record_id,
  po.ticket_number AS purchase_order_ticket_number,
  po.payment_mode AS purchase_order_payment_mode,
  po.timezone AS purchase_order_timezone,
  po.created_at AS purchase_order_created_at,
  po.deleted_at AS purchase_order_deleted_at,
  po.free_access AS purchase_order_free_access,

  -- Producto
  p.id AS product_id,
  p.record_id AS product_record_id,
  p.name AS product_name,
  p.alias AS product_alias,
  pt.name AS product_type,
  p.is_free AS product_is_free,
  p.availability_type AS product_availability_type,
  p.total_resources AS product_total_resources,
  p.total_duration AS product_total_duration,
  p.total_size AS product_total_size,
  p.total_sections AS product_total_sections,
  p.duration_unit AS product_duration_unit,
  p.duration_quantity AS product_duration_quantity,
  p.deleted_at AS product_deleted_at,
  p.description AS product_description,
  p.location_cache AS product_location,
  p.featured_media_cache AS product_featured_media,
  p.post_booking_steps_cache AS post_booking_steps_cache,

  -- Plan
  pp.id AS plan_id,
  pp.record_id AS plan_record_id,
  pp.checkout_id AS plan_checkout_id,
  pp.name AS plan_name,
  pp.description AS plan_description,
  pp.pricing_model AS plan_pricing_model,
  
  -- new 
  pp.total_resources AS plan_total_resources,
  pp.total_duration AS plan_total_duration,
  pp.total_size AS plan_total_size,
  pp.total_sections AS plan_total_sections,

  -- Fecha (si aplica)
  pd.id AS product_date_id,
  pd.record_id AS product_date_record_id,
  pd.initial_date AS product_initial_date,
  pd.end_date AS product_end_date,
  pd.timezone AS product_date_timezone,

  -- Host (creador)
  h.id AS host_id,
  h.record_id AS host_record_id,
  h.name AS host_name,
  h.alias AS host_alias,
  h.email AS host_email,
  h.phone_code AS host_phone_code,
  h.phone_number AS host_phone_number,
  h.tags AS host_tags,
  h.logo_cache AS host_logo

FROM app_core.user_access ua
LEFT JOIN app_core.purchase_order po
  ON po.id = ua.purchase_order_id

LEFT JOIN app_core.product p
  ON p.id = ua.product_id

INNER JOIN app_core.product_type pt
  ON pt.id = p.product_type_id

LEFT JOIN app_core.product_plan pp
  ON pp.id = ua.plan_id

LEFT JOIN app_core.product_date pd
  ON pd.id = ua.date_id

LEFT JOIN app_core.host h
  ON h.id = p.host_id;


CREATE OR REPLACE VIEW app_core.vw_product_resource AS
SELECT
    prr.id AS relation_id,
    prr.product_id,
    prr.resource_id,

    r.record_id AS resource_record_id,
    r.host_id,
    r.parent_id,
    r.path,
    r.type,
    r.file_type,
    r.filename,
    r.title,
    r.description,
    r.long_description,
    r.duration,
    r.size,
    r.url,
    r.source,
    r.file_id,
    r.processing_status,
    r.encode_progress,
    r.thumbnail,
    r.preview,
    r.downloadable,
    r.created_at AS resource_created_at,
    r.updated_at AS resource_updated_at,

    -- atributos propios del producto
    prr.order_index,
    prr.total_views,
    prr.restricted,
    prr.status AS relation_status,
    prr.created_at AS relation_created_at,
    prr.updated_at AS relation_updated_at

FROM app_core.product_resource_relation prr
RIGHT JOIN app_core.resource r ON r.id = prr.resource_id;


CREATE OR REPLACE VIEW app_core.vw_host_customers AS
SELECT 
    c.id AS customer_id,
    c.record_id AS customer_record_id,
    c.host_id,
    c.user_id,
    c.total_orders,
    c.created_at AS customer_created_at,
    c.updated_at AS customer_updated_at,

    u.record_id AS user_record_id,
    u.first_name,
    u.last_name,
    u.full_name,
    u.email,
    u.phone_code,
    u.phone_number,
    u.timezone,
    u.verified_email,
    u.is_host,
    u.is_referrer,

    -- 🏷️ Tags (etiquetas agregadas)
    COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'tag_id', t.id,
                'tag_record_id', t.record_id,
                'key', t.key,
                'value', t.value,
                'color', t.color,
                'description', t.description
            )
        ) FILTER (WHERE t.id IS NOT NULL), '[]'::jsonb
    ) AS tags,
    u.instagram_account


FROM app_core.customer c
JOIN app_core.app_user u ON u.id = c.user_id
LEFT JOIN app_core.customer_tag_relation ctr ON ctr.customer_id = c.id
LEFT JOIN app_core.customer_tag t ON t.id = ctr.tag_id

GROUP BY 
    c.id, c.record_id, c.host_id, c.user_id, c.total_orders,
    c.created_at, c.updated_at,
    u.record_id, u.first_name, u.last_name, u.full_name, u.email, 
   u.phone_code, u.phone_number, u.timezone, u.verified_email,
    u.is_host, u.is_referrer,  u.instagram_account;



CREATE OR REPLACE VIEW app_core.vw_purchase_orders_search AS
SELECT
    -- Purchase Order
    po.id AS purchase_order_id,
    po.record_id AS purchase_order_record_id,
    po.ticket_number,
    po.host_id,
    po.created_at,
    po.updated_at,
    po.payment_mode,
    po.is_test,
    po.free_access,
    po.installments_program_applied,
    po.payment_status,
    po.subtotal,
    po.discount,
    po.installment_fee,
    po.platform_fee,
    po.taxes_fee,
    po.commissionable_amount,
    po.net_revenue,
    po.total,
    po.deleted_at,

    -- Product
    poi.product_id,
    p.record_id AS product_record_id,
    p.name AS product_name,

    -- Buyer
    u.id AS buyer_id,
    u.record_id AS buyer_record_id,
    u.first_name AS buyer_first_name,
    u.last_name AS buyer_last_name,
    u.full_name AS buyer_full_name,
    u.email AS buyer_email,
    u.phone_code AS buyer_phone_code,
    u.phone_number AS buyer_phone_number,

    -- Plan
    pp.id AS plan_id,
    pp.record_id AS plan_record_id,
    pp.checkout_id AS plan_checkout_id,
    pp.name AS plan_name,
    pp.description AS plan_description,
    pp.price AS plan_price,
    pp.pricing_model AS plan_pricing_model,
    pp.currency AS plan_currency,

    -- Date
    pd.id AS date_id,
    pd.record_id AS date_record_id,
    pd.initial_date,
    pd.end_date,
    
    -- Session
    poi.session_start_date,
    poi.session_end_date,

    -- Métodos de pago (as JSONB array)
    COALESCE(
        to_jsonb(array_agg(DISTINCT pm.key) FILTER (WHERE pm.key IS NOT NULL))::jsonb,
        '[]'::jsonb
    ) AS payment_methods

FROM app_core.purchase_order po
LEFT JOIN app_core.purchase_order_item poi ON poi.purchase_order_id = po.id
LEFT JOIN app_core.product p ON p.id = poi.product_id  
LEFT JOIN app_core.product_plan pp ON pp.id = poi.plan_id
LEFT JOIN app_core.product_date pd ON pd.id = poi.date_id
LEFT JOIN app_core.app_user u ON u.id = po.buyer_id
LEFT JOIN app_core.payment pay ON pay.purchase_order_id = po.id
LEFT JOIN app_core.payment_method pm ON pm.id = pay.payment_method_id

GROUP BY
    -- Purchase Order
    po.id, po.record_id, po.ticket_number, po.host_id,
    po.created_at, po.updated_at, po.payment_mode,
    po.is_test, po.free_access, po.installments_program_applied, po.payment_status,
    po.subtotal, po.discount, po.installment_fee, po.platform_fee, po.taxes_fee, po.total,
    po.deleted_at,

    -- Product
    poi.product_id, p.record_id, p.name,

    -- Buyer
    u.id, u.record_id, u.first_name, u.last_name,
    u.full_name, u.email, u.phone_code, u.phone_number,

    -- Plan
    pp.id, pp.record_id, pp.checkout_id,
    pp.name, pp.description, pp.price, pp.pricing_model, pp.currency,

    -- Date
    pd.id, pd.record_id, pd.initial_date, pd.end_date,

    -- Session
    poi.session_start_date, poi.session_end_date;


CREATE OR REPLACE VIEW app_core.vw_host_daily_revenue AS
SELECT 
    po.host_id,
    date_trunc('day', po.created_at) AS day,
    SUM(po.total) AS gross_revenue, -- total received by the host (before platform commission)
    SUM(po.net_revenue) AS total_revenue, -- total received by the host (after platform commission) 
    COUNT(*) AS total_orders
FROM app_core.purchase_order po
WHERE po.deleted_at IS NULL
GROUP BY po.host_id, date_trunc('day', po.created_at);



CREATE OR REPLACE VIEW app_core.vw_question_search_view AS
SELECT
    q.id AS question_id,
    q.record_id AS question_record_id,
    q.resource_id,
    q.text AS question_text,
    q.question_type,
    q.order_index AS question_order,
    q.explanation,
    q.rating_scale,
    q.min_rating_label,
    q.max_rating_label,
    q.is_required,
    q.created_at AS question_created_at,
    q.updated_at AS question_updated_at,
    q.points, 

    ao.id AS option_id,
    ao.record_id AS option_record_id,
    ao.text AS option_text,
    ao.order_index AS option_order,

    r.record_id AS resource_record_id,
    r.title AS resource_title,
    r.type AS resource_type,

    h.id AS host_id,
    h.record_id AS host_record_id,
    h.name AS host_name,
    h.alias AS host_alias

FROM app_core.question q
JOIN app_core.resource r 
    ON r.id = q.resource_id
JOIN app_core.host h 
    ON h.id = r.host_id
LEFT JOIN app_core.answer_option ao 
    ON ao.question_id = q.id;



create view app_core.vw_payments_detail as
select
  h.id as host_id,
  h.record_id as host_record_id,
  h.name as host_name,
  p.id as payment_id,
  p.record_id as payment_record_id,
  p.payment_status,
  p.total as payment_total,
  p.total_converted as payment_total_converted,
  p.exchange_rate as payment_exchange_rate,
  p.created_at as payment_created_at,
  p.platform_fee as payment_platform_fee,
  p.gateway_fee as payment_gateway_fee,
  po.id as purchase_id,
  po.record_id as purchase_record_id,
  po.ticket_number as purchase_ticket_number,
  po.payment_mode as purchase_payment_mode,
  po.payment_status as purchase_payment_status,
  po.commission_payer as purchase_commission_payer,
  po.subtotal as purchase_subtotal,
  po.discount as purchase_discount,
  po.installment_fee as purchase_installment_fee,
  po.platform_fee as purchase_platform_fee,
  po.total as purchase_total,
  po.created_at as purchase_created_at,
  po.updated_at as purchase_updated_at,
  po.deleted_at as purchase_deleted_at,
  poi.product_id,
  pro.record_id as product_record_id,
  pro.name as product_name,
  ps.id as payment_split_id,
  ps.record_id as payment_split_record_id,
  ps.beneficiary_type as payment_split_beneficiary_type,
  ps.beneficiary_user_id as payment_split_beneficiary_user_id,
  ps.base_amount as payment_split_base_amount,
  ps.percentage as payment_split_percentage,
  ps.amount as payment_split_amount,
  ps.amount_converted as payment_split_amount_converted,
  ps.due_date as payment_split_due_date,
  ps.grace_period_end_date as payment_split_grace_period_end_date,
  ps.paid_at as payment_split_paid_at,
  ps.is_overdue as payment_split_is_overdue,
  ps.status as payment_split_status,
  ps.invoice_id as payment_split_invoice_id,
  i.record_id as invoice_record_id,
  case
    when ps.beneficiary_type::text = 'PLATFORM_COMMISSION'::text then (
      select
        jsonb_agg(
          jsonb_build_object(
            'id',
            popf.id,
            'purchase_order_item_id',
            popf.purchase_order_item_id,
            'percentage',
            popf.percentage,
            'key',
            popf.key,
            'amount',
            popf.amount,
            'created_at',
            popf.created_at
          )
          order by
            popf.created_at
        ) as jsonb_agg
      from
        app_core.purchase_order_platform_fee popf
      where
        popf.purchase_order_id = po.id
    )
    else null::jsonb
  end as platform_fees,
  c.code as payment_currency_code,
  c.symbol as payment_currency_symbol
from
  app_core.payment p
  left join app_core.payment_split ps on ps.payment_id = p.id
  left join app_core.invoice i on i.id = ps.invoice_id
  left join app_core.purchase_order po on po.id = p.purchase_order_id
  left join app_core.purchase_order_item poi on poi.purchase_order_id = po.id
  left join app_core.product pro on pro.id = poi.product_id
  left join app_core.host h on h.id = po.host_id
  left join app_core.payment_method pm on pm.id = p.payment_method_id
  left join app_core.currency c on c.id = pm.currency_id
order by
  p.created_at desc;


-- ================================================
-- INSERTS PARA TABLAS GENERALES
-- ================================================

-- ================================================
-- CURRENCY
-- ================================================
INSERT INTO app_core.currency (code, symbol, created_at, updated_at) VALUES
('USD', '$', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('VES', 'Bs.', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- ================================================
-- PRODUCT_TYPE
-- ================================================
INSERT INTO app_core.product_type (name, total_products, icon, status) VALUES
('EVENT', 0, 'event', 'ACTIVE'),
('DIGITAL_PRODUCT', 0, 'digital-product', 'ACTIVE'),
('ONE_TO_ONE_SESSION', 0, 'one-to-one-session', 'ACTIVE'),
('DIGITAL_COURSE', 0, 'digital-course', 'ACTIVE');

-- ================================================
-- MEETING_PLATFORM
-- ================================================
INSERT INTO app_core.meeting_platform (key, description) VALUES
('ZOOM', 'Zoom video conferencing platform'),
('GOOGLE_MEETS', 'Google Meets video conferencing'),
('MICROSOFT_TEAMS', 'Microsoft Teams collaboration platform'),
('CUSTOM', 'Custom meeting platform or link'),
('NONE', 'No meeting platform required');


-- ================================================
-- APP_SETTINGS
-- ================================================

INSERT INTO app_core.app_settings (
    settings_group,
    key,
    value,
    value_type,
    country,
    description,
    status
)
VALUES (
    'TAX_CONFIG',              -- agrupación lógica
    'IVA',            -- clave identificadora del impuesto
    '16.00',                   -- valor del IVA
    'PERCENTAGE',              -- tipo de valor: porcentaje
    'VE',                      -- código ISO del país (Venezuela)
    'IVA general del 16% aplicado a productos y servicios estándar',
    'INACTIVE'
);



-- ================================================
-- ROLE
-- ================================================
-- Basado en el enum Role y roles mencionados (OWNER, ADMIN, EDITOR, VIEWER)
INSERT INTO app_core.role (key, description, created_at, updated_at) VALUES
('OWNER', 'Owner with full administrative privileges', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('ADMIN', 'Administrator with management privileges', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('EDITOR', 'Editor with content creation and modification privileges', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('VIEWER', 'Viewer with read-only access', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('GUEST', 'Guest user with limited access', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- ================================================
-- PAYMENT_METHOD
-- ================================================
-- Basado en PaymentMethod enum y payment-methods.constant.ts
-- Primero necesitamos obtener los IDs de las monedas
WITH currency_ids AS (
    SELECT id as usd_id FROM app_core.currency WHERE code = 'USD'
), currency_ids_ves AS (
    SELECT id as ves_id FROM app_core.currency WHERE code = 'VES'
)
INSERT INTO app_core.payment_method (key, icon, requires_coordination, requires_receipt, processor_type, automatic, currency_id, status, created_at, updated_at) 
SELECT 
    pm.key,
    pm.icon,
    pm.requires_coordination,
    pm.requires_receipt,
    pm.processor_type,
    pm.automatic,
    CASE 
        WHEN pm.currency = 'USD' THEN (SELECT usd_id FROM currency_ids)
        WHEN pm.currency = 'VES' THEN (SELECT ves_id FROM currency_ids_ves)
    END as currency_id,
    'ACTIVE'::app_core.common_status as status,
    CURRENT_TIMESTAMP as created_at,
    CURRENT_TIMESTAMP as updated_at
FROM (VALUES
    ('MOBILE_PAYMENT', 'phone', false, true, 'MANUAL', false, 'VES'),
    ('CASH', 'cash', true, false, 'MANUAL', false, 'USD'),
    ('ZELLE', 'zelle', false, true, 'MANUAL', false, 'USD'),
    ('BINANCE', 'binance', false, true, 'MANUAL', false, 'USD'),
    ('PAYPAL', 'paypal', false, true, 'MANUAL', false, 'USD'),
    ('ZINLI', 'zinli', false, true, 'MANUAL', false, 'USD'),
    ('AUTOMATIC_MOBILE_PAYMENT', 'mobile', false, false, 'AUTOMATIC_MOBILE_PAYMENT', true, 'VES')
) AS pm(key, icon, requires_coordination, requires_receipt, processor_type, automatic, currency);


INSERT INTO app_core.payment_fee_rule (payment_method_id, direction, fee_percent, fee_fixed, assumed_by, country) VALUES
(
    (SELECT id FROM app_core.payment_method WHERE key = 'AUTOMATIC_MOBILE_PAYMENT'),
    'IN',
    150,
    0,
    'HOST',
    'VE'
);


-- ================================================
-- BILLING_PLAN
-- ================================================
INSERT INTO app_core.billing_plan (key, description, features, status, created_at, updated_at) VALUES
(
    'BASIC',
    'Plan básico con comisión porcentual y fija por reserva',
    '["7.9% de comisión por reserva", "$0.44 fijos por reserva"]'::jsonb,
    'ACTIVE'::app_core.common_status,
    '2025-01-01T00:00:00Z'::timestamptz,
    '2025-01-01T10:00:00Z'::timestamptz
),
(
    'BASIC-EARLY-BIRD',
    'Plan básico con comisión porcentual',
    '["6% de comisión por reserva"]'::jsonb,
    'ACTIVE'::app_core.common_status,
    '2025-01-01T00:00:00Z'::timestamptz,
    '2025-01-01T10:00:00Z'::timestamptz
);

-- ================================================
-- PLAN_BREAKDOWN
-- ================================================
-- Basado en el breakdown del plan BASIC

INSERT INTO app_core.plan_breakdown (billing_plan_id, billing_type, key, type, amount)
VALUES
((SELECT id FROM app_core.billing_plan WHERE key = 'BASIC'), 'STANDARD', 'STANDARD_PERCENTAGE_FEE', 'PERCENTAGE', 790),
((SELECT id FROM app_core.billing_plan WHERE key = 'BASIC'), 'MEDIA_ACCESS', 'MEDIA_ACCESS_PERCENTAGE_FEE', 'PERCENTAGE', 790),
((SELECT id FROM app_core.billing_plan WHERE key = 'BASIC'), 'VIDEO_ACCESS', 'VIDEO_ACCESS_PERCENTAGE_FEE', 'PERCENTAGE', 790),
((SELECT id FROM app_core.billing_plan WHERE key = 'BASIC'), 'STANDARD', 'COMMON_FIXED_FEE', 'FIXED', 44);

-- ================================================
-- DISCOUNT
-- ================================================
-- Basado en los ejemplos de cupones proporcionados
INSERT INTO app_core.discount (
    record_id,
    owner_type,
    name, 
    description, 
    percentage, 
    status, 
    valid_from, 
    valid_until, 
    code, 
    duration_quantity, 
    conditions,
    created_at, 
    updated_at
) VALUES
-- GUAYABITO2025
(
    '1ab2c3d4-e5f6-7890-abcd-ef1234567891',
    'APP',
    'GUAYABITO2025',
    '25% de descuento en comisiones por el primer mes',
    2500,
    'ACTIVE'::app_core.common_status,
    '2025-03-15T10:30:00.000Z'::timestamptz,
    '2025-04-15T10:30:00.000Z'::timestamptz,
    'GUAYABITO2025',
    30, -- duration_quantity en días (1 mes = 30 días)
    '{}'::jsonb, -- conditions vacío
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
),
-- GUAYABITOSTOP
(
    '1ab2c3d4-e5f6-7890-abcd-ef1234567892',
    'APP',
    'GUAYABITOSTOP',
    '80% de descuento en comisiones por ser embajador de Guaybo',
    8000,
    'ACTIVE'::app_core.common_status,
    NULL, -- no tiene validFrom
    NULL, -- no tiene validUntil
    'GUAYABITOSTOP',
    60, -- duration_quantity en días (2 meses = 60 días)
    '{}'::jsonb, -- conditions vacío
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
),
-- QUIEROVENDER
(
    '1ab2c3d4-e5f6-7890-abcd-ef1234567893',
    'APP',
    'QUIEROVENDER',
    '50% de descuento en comisiones por el primer mes',
    5000,
    'ACTIVE'::app_core.common_status,
    '2025-06-01T10:30:00.000Z'::timestamptz,
    '2025-09-10T10:30:00.000Z'::timestamptz,
    'QUIEROVENDER',
    30, -- duration_quantity en días (1 mes = 30 días)
    '{}'::jsonb, -- conditions vacío
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);

-- ================================================
-- PAYMENT_OPTION
-- ================================================
INSERT INTO app_core.payment_option (record_id, owner_type, payment_method_id, custom_attributes, status, created_at, updated_at) VALUES
(
    '28d23974-191e-4c1f-9455-05c7fa2576fd',
    'APP',
    (SELECT id FROM app_core.payment_method WHERE key = 'MOBILE_PAYMENT'),
    '{
    "bank":  {
        "key": "BANCO_DE_VENEZUELA",
        "name": "(0102) BANCO DE VENEZUELA"
    },
    "description": {
        "required": false,
        "type": "string"
    },
    "nationalId": "V26825288",
    "phoneNumber": {
        "code": "58",
        "number": "4124787905"
    }
}'::jsonb,
    'ACTIVE',
    '2025-02-08 01:41:36.256+00',
    '2025-02-08 01:41:36.257+00'
),
(
    'a18ba64c-a810-48fd-adaa-e84591c78a4e',
    'APP',
    (SELECT id FROM app_core.payment_method WHERE key = 'CASH'),
    '{
      "description": "Te contactará el equipo interno de Guaybo para concretar el pago."
    }'::jsonb,
    'ACTIVE',
    '2025-02-14 19:46:53.997+00',
    '2025-02-14 19:46:53.997+00'
);

-- ================================================
-- VERIFICACIÓN DE INSERTS
-- ================================================

-- Verificar que se insertaron correctamente
SELECT 'currency' as table_name, COUNT(*) as total_records FROM app_core.currency
UNION ALL
SELECT 'role' as table_name, COUNT(*) as total_records FROM app_core.role
UNION ALL
SELECT 'payment_method' as table_name, COUNT(*) as total_records FROM app_core.payment_method
UNION ALL
SELECT 'billing_plan' as table_name, COUNT(*) as total_records FROM app_core.billing_plan
UNION ALL
SELECT 'plan_breakdown' as table_name, COUNT(*) as total_records FROM app_core.plan_breakdown
UNION ALL
SELECT 'discount' as table_name, COUNT(*) as total_records FROM app_core.discount
UNION ALL
SELECT 'payment_option' as table_name, COUNT(*) as total_records FROM app_core.payment_option
ORDER BY table_name;

-- Verificar datos específicos
SELECT 'Currency details:' as info;
SELECT code, symbol FROM app_core.currency ORDER BY code;

SELECT 'Payment methods with currency:' as info;
SELECT pm.key, pm.icon, pm.requires_coordination, pm.automatic, c.code as currency
FROM app_core.payment_method pm
JOIN app_core.currency c ON pm.currency_id = c.id
ORDER BY pm.key;

SELECT 'Billing plan with breakdown:' as info;
SELECT bp.key, bp.description, pb.key as breakdown_key, pb.type, pb.amount
FROM app_core.billing_plan bp
JOIN app_core.plan_breakdown pb ON bp.id = pb.billing_plan_id
ORDER BY bp.key, pb.id;

SELECT 'Discounts:' as info;
SELECT code, percentage, valid_from, valid_until, duration_quantity
FROM app_core.discount
ORDER BY code;

SELECT 'Payment options:' as info;
SELECT po.record_id, po.owner_type, pm.key as payment_method
FROM app_core.payment_option po
JOIN app_core.payment_method pm ON po.payment_method_id = pm.id
ORDER BY po.id;
