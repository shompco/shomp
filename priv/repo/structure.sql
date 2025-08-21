--
-- PostgreSQL database dump
--

-- Dumped from database version 14.15 (Homebrew)
-- Dumped by pg_dump version 14.15 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cart_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cart_items (
    id bigint NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    price numeric(10,2) NOT NULL,
    cart_id bigint NOT NULL,
    product_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: cart_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cart_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cart_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cart_items_id_seq OWNED BY public.cart_items.id;


--
-- Name: carts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carts (
    id bigint NOT NULL,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    total_amount numeric(10,2) DEFAULT 0.0 NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    store_id character varying(255) NOT NULL
);


--
-- Name: carts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.carts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: carts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.carts_id_seq OWNED BY public.carts.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    level integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    parent_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id bigint NOT NULL,
    content text,
    created_at timestamp(0) without time zone,
    request_id bigint,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: downloads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.downloads (
    id bigint NOT NULL,
    token character varying(255) NOT NULL,
    download_count integer DEFAULT 0 NOT NULL,
    expires_at timestamp(0) without time zone,
    last_downloaded_at timestamp(0) without time zone,
    product_id bigint NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: downloads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.downloads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: downloads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.downloads_id_seq OWNED BY public.downloads.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    price numeric(10,2) NOT NULL,
    created_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    immutable_id character varying(255) NOT NULL,
    user_id bigint NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    stripe_session_id character varying(255) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    amount numeric(10,2) NOT NULL,
    stripe_payment_id character varying(255) NOT NULL,
    product_id bigint NOT NULL,
    user_id bigint NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id bigint NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    type character varying(255) NOT NULL,
    file_path character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    stripe_product_id character varying(255),
    store_id character varying(255) NOT NULL,
    category_id bigint,
    image_original character varying(255),
    image_thumb character varying(255),
    image_medium character varying(255),
    image_large character varying(255),
    image_extra_large character varying(255),
    image_ultra character varying(255),
    additional_images character varying(255)[] DEFAULT ARRAY[]::character varying[],
    primary_image_index integer DEFAULT 0
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.requests (
    id bigint NOT NULL,
    title character varying(255),
    description text,
    status character varying(255),
    priority integer,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.requests_id_seq OWNED BY public.requests.id;


--
-- Name: review_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_flags (
    id bigint NOT NULL,
    reason character varying(255) NOT NULL,
    description text,
    resolved boolean DEFAULT false NOT NULL,
    review_id bigint NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: review_flags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.review_flags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: review_flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.review_flags_id_seq OWNED BY public.review_flags.id;


--
-- Name: review_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_responses (
    id bigint NOT NULL,
    content text NOT NULL,
    review_id bigint NOT NULL,
    store_id bigint NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: review_responses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.review_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: review_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.review_responses_id_seq OWNED BY public.review_responses.id;


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id bigint NOT NULL,
    rating integer NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    verified_purchase boolean DEFAULT false NOT NULL,
    moderated boolean DEFAULT false NOT NULL,
    flagged_count integer DEFAULT 0 NOT NULL,
    store_id bigint NOT NULL,
    product_id bigint NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviews_id_seq OWNED BY public.reviews.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: store_balances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_balances (
    id bigint NOT NULL,
    total_earnings numeric(10,2) DEFAULT 0.0 NOT NULL,
    pending_balance numeric(10,2) DEFAULT 0.0 NOT NULL,
    paid_out_balance numeric(10,2) DEFAULT 0.0 NOT NULL,
    last_payout_date timestamp(0) without time zone,
    kyc_verified boolean DEFAULT false NOT NULL,
    kyc_verified_at timestamp(0) without time zone,
    kyc_documents_submitted boolean DEFAULT false NOT NULL,
    kyc_submitted_at timestamp(0) without time zone,
    store_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: store_balances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.store_balances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: store_balances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.store_balances_id_seq OWNED BY public.store_balances.id;


--
-- Name: store_kyc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_kyc (
    id bigint NOT NULL,
    legal_name character varying(255) NOT NULL,
    business_type character varying(255) NOT NULL,
    tax_id character varying(255) NOT NULL,
    address_line_1 character varying(255) NOT NULL,
    address_line_2 character varying(255),
    city character varying(255) NOT NULL,
    state character varying(255) NOT NULL,
    zip_code character varying(255) NOT NULL,
    country character varying(255) DEFAULT 'US'::character varying NOT NULL,
    phone character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    id_document_path character varying(255),
    business_license_path character varying(255),
    tax_document_path character varying(255),
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    submitted_at timestamp(0) without time zone,
    verified_at timestamp(0) without time zone,
    rejected_at timestamp(0) without time zone,
    rejection_reason character varying(255),
    admin_notes text,
    store_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: store_kyc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.store_kyc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: store_kyc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.store_kyc_id_seq OWNED BY public.store_kyc.id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    description text,
    user_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    store_id character varying(255) NOT NULL
);


--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- Name: tiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tiers (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    store_limit integer NOT NULL,
    product_limit_per_store integer NOT NULL,
    monthly_price numeric(10,2) NOT NULL,
    features character varying(255)[] DEFAULT ARRAY[]::character varying[],
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255),
    confirmed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    name character varying(255) NOT NULL,
    role character varying(255) DEFAULT 'user'::character varying NOT NULL,
    username character varying(255),
    tier_id uuid,
    trial_ends_at timestamp(0) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: users_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    authenticated_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_tokens_id_seq OWNED BY public.users_tokens.id;


--
-- Name: votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.votes (
    id bigint NOT NULL,
    weight integer,
    request_id bigint,
    user_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.votes_id_seq OWNED BY public.votes.id;


--
-- Name: cart_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items ALTER COLUMN id SET DEFAULT nextval('public.cart_items_id_seq'::regclass);


--
-- Name: carts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts ALTER COLUMN id SET DEFAULT nextval('public.carts_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: downloads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downloads ALTER COLUMN id SET DEFAULT nextval('public.downloads_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests ALTER COLUMN id SET DEFAULT nextval('public.requests_id_seq'::regclass);


--
-- Name: review_flags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_flags ALTER COLUMN id SET DEFAULT nextval('public.review_flags_id_seq'::regclass);


--
-- Name: review_responses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses ALTER COLUMN id SET DEFAULT nextval('public.review_responses_id_seq'::regclass);


--
-- Name: reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews ALTER COLUMN id SET DEFAULT nextval('public.reviews_id_seq'::regclass);


--
-- Name: store_balances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_balances ALTER COLUMN id SET DEFAULT nextval('public.store_balances_id_seq'::regclass);


--
-- Name: store_kyc id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_kyc ALTER COLUMN id SET DEFAULT nextval('public.store_kyc_id_seq'::regclass);


--
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: users_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens ALTER COLUMN id SET DEFAULT nextval('public.users_tokens_id_seq'::regclass);


--
-- Name: votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes ALTER COLUMN id SET DEFAULT nextval('public.votes_id_seq'::regclass);


--
-- Name: cart_items cart_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT cart_items_pkey PRIMARY KEY (id);


--
-- Name: carts carts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT carts_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: downloads downloads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downloads
    ADD CONSTRAINT downloads_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);


--
-- Name: review_flags review_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_flags
    ADD CONSTRAINT review_flags_pkey PRIMARY KEY (id);


--
-- Name: review_responses review_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: store_balances store_balances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_balances
    ADD CONSTRAINT store_balances_pkey PRIMARY KEY (id);


--
-- Name: store_kyc store_kyc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_kyc
    ADD CONSTRAINT store_kyc_pkey PRIMARY KEY (id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: tiers tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiers
    ADD CONSTRAINT tiers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_tokens users_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_pkey PRIMARY KEY (id);


--
-- Name: votes votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- Name: cart_items_cart_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cart_items_cart_id_index ON public.cart_items USING btree (cart_id);


--
-- Name: cart_items_cart_id_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cart_items_cart_id_product_id_index ON public.cart_items USING btree (cart_id, product_id);


--
-- Name: cart_items_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cart_items_inserted_at_index ON public.cart_items USING btree (inserted_at);


--
-- Name: cart_items_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cart_items_product_id_index ON public.cart_items USING btree (product_id);


--
-- Name: carts_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX carts_inserted_at_index ON public.carts USING btree (inserted_at);


--
-- Name: carts_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX carts_status_index ON public.carts USING btree (status);


--
-- Name: carts_store_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX carts_store_id_index ON public.carts USING btree (store_id);


--
-- Name: carts_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX carts_user_id_index ON public.carts USING btree (user_id);


--
-- Name: categories_level_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_level_index ON public.categories USING btree (level);


--
-- Name: categories_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_parent_id_index ON public.categories USING btree (parent_id);


--
-- Name: categories_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX categories_slug_index ON public.categories USING btree (slug);


--
-- Name: comments_request_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_request_id_index ON public.comments USING btree (request_id);


--
-- Name: comments_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_user_id_index ON public.comments USING btree (user_id);


--
-- Name: downloads_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX downloads_expires_at_index ON public.downloads USING btree (expires_at);


--
-- Name: downloads_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX downloads_inserted_at_index ON public.downloads USING btree (inserted_at);


--
-- Name: downloads_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX downloads_product_id_index ON public.downloads USING btree (product_id);


--
-- Name: downloads_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX downloads_token_index ON public.downloads USING btree (token);


--
-- Name: downloads_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX downloads_user_id_index ON public.downloads USING btree (user_id);


--
-- Name: order_items_order_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_order_id_index ON public.order_items USING btree (order_id);


--
-- Name: order_items_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_product_id_index ON public.order_items USING btree (product_id);


--
-- Name: orders_immutable_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX orders_immutable_id_index ON public.orders USING btree (immutable_id);


--
-- Name: orders_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_status_index ON public.orders USING btree (status);


--
-- Name: orders_stripe_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_stripe_session_id_index ON public.orders USING btree (stripe_session_id);


--
-- Name: orders_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_user_id_index ON public.orders USING btree (user_id);


--
-- Name: payments_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_product_id_index ON public.payments USING btree (product_id);


--
-- Name: payments_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_status_index ON public.payments USING btree (status);


--
-- Name: payments_stripe_payment_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX payments_stripe_payment_id_index ON public.payments USING btree (stripe_payment_id);


--
-- Name: payments_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_user_id_index ON public.payments USING btree (user_id);


--
-- Name: products_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_category_id_index ON public.products USING btree (category_id);


--
-- Name: products_image_original_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_image_original_index ON public.products USING btree (image_original);


--
-- Name: products_image_thumb_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_image_thumb_index ON public.products USING btree (image_thumb);


--
-- Name: products_store_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_store_id_index ON public.products USING btree (store_id);


--
-- Name: products_stripe_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_stripe_product_id_index ON public.products USING btree (stripe_product_id);


--
-- Name: products_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX products_type_index ON public.products USING btree (type);


--
-- Name: requests_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX requests_user_id_index ON public.requests USING btree (user_id);


--
-- Name: review_flags_resolved_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX review_flags_resolved_index ON public.review_flags USING btree (resolved);


--
-- Name: review_flags_review_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX review_flags_review_id_index ON public.review_flags USING btree (review_id);


--
-- Name: review_flags_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX review_flags_user_id_index ON public.review_flags USING btree (user_id);


--
-- Name: review_responses_review_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX review_responses_review_id_index ON public.review_responses USING btree (review_id);


--
-- Name: review_responses_store_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX review_responses_store_id_index ON public.review_responses USING btree (store_id);


--
-- Name: review_responses_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX review_responses_user_id_index ON public.review_responses USING btree (user_id);


--
-- Name: reviews_product_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reviews_product_id_index ON public.reviews USING btree (product_id);


--
-- Name: reviews_rating_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reviews_rating_index ON public.reviews USING btree (rating);


--
-- Name: reviews_store_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reviews_store_id_index ON public.reviews USING btree (store_id);


--
-- Name: reviews_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reviews_user_id_index ON public.reviews USING btree (user_id);


--
-- Name: reviews_verified_purchase_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reviews_verified_purchase_index ON public.reviews USING btree (verified_purchase);


--
-- Name: store_balances_kyc_verified_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX store_balances_kyc_verified_index ON public.store_balances USING btree (kyc_verified);


--
-- Name: store_balances_pending_balance_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX store_balances_pending_balance_index ON public.store_balances USING btree (pending_balance);


--
-- Name: store_balances_store_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX store_balances_store_id_index ON public.store_balances USING btree (store_id);


--
-- Name: store_kyc_business_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX store_kyc_business_type_index ON public.store_kyc USING btree (business_type);


--
-- Name: store_kyc_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX store_kyc_status_index ON public.store_kyc USING btree (status);


--
-- Name: store_kyc_store_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX store_kyc_store_id_index ON public.store_kyc USING btree (store_id);


--
-- Name: store_kyc_tax_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX store_kyc_tax_id_index ON public.store_kyc USING btree (tax_id);


--
-- Name: stores_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX stores_slug_index ON public.stores USING btree (slug);


--
-- Name: stores_store_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX stores_store_id_index ON public.stores USING btree (store_id);


--
-- Name: stores_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stores_user_id_index ON public.stores USING btree (user_id);


--
-- Name: tiers_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tiers_slug_index ON public.tiers USING btree (slug);


--
-- Name: tiers_sort_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tiers_sort_order_index ON public.tiers USING btree (sort_order);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: users_tier_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tier_id_index ON public.users USING btree (tier_id);


--
-- Name: users_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_tokens_context_token_index ON public.users_tokens USING btree (context, token);


--
-- Name: users_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tokens_user_id_index ON public.users_tokens USING btree (user_id);


--
-- Name: users_username_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_index ON public.users USING btree (username);


--
-- Name: votes_request_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX votes_request_id_index ON public.votes USING btree (request_id);


--
-- Name: votes_request_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX votes_request_id_user_id_index ON public.votes USING btree (request_id, user_id);


--
-- Name: votes_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX votes_user_id_index ON public.votes USING btree (user_id);


--
-- Name: cart_items cart_items_cart_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT cart_items_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES public.carts(id) ON DELETE CASCADE;


--
-- Name: cart_items cart_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_items
    ADD CONSTRAINT cart_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: carts carts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carts
    ADD CONSTRAINT carts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: comments comments_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.requests(id) ON DELETE CASCADE;


--
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: downloads downloads_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downloads
    ADD CONSTRAINT downloads_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: downloads downloads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.downloads
    ADD CONSTRAINT downloads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: orders orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: payments payments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: requests requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: review_flags review_flags_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_flags
    ADD CONSTRAINT review_flags_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE CASCADE;


--
-- Name: review_flags review_flags_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_flags
    ADD CONSTRAINT review_flags_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: review_responses review_responses_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE CASCADE;


--
-- Name: review_responses review_responses_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: review_responses review_responses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_responses
    ADD CONSTRAINT review_responses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: store_balances store_balances_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_balances
    ADD CONSTRAINT store_balances_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: store_kyc store_kyc_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_kyc
    ADD CONSTRAINT store_kyc_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: stores stores_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_tier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_tier_id_fkey FOREIGN KEY (tier_id) REFERENCES public.tiers(id) ON DELETE RESTRICT;


--
-- Name: users_tokens users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: votes votes_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.requests(id) ON DELETE CASCADE;


--
-- Name: votes votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20250120000000);
INSERT INTO public."schema_migrations" (version) VALUES (20250815224808);
INSERT INTO public."schema_migrations" (version) VALUES (20250817055853);
INSERT INTO public."schema_migrations" (version) VALUES (20250817061147);
INSERT INTO public."schema_migrations" (version) VALUES (20250817063522);
INSERT INTO public."schema_migrations" (version) VALUES (20250817064703);
INSERT INTO public."schema_migrations" (version) VALUES (20250817070835);
INSERT INTO public."schema_migrations" (version) VALUES (20250819024330);
INSERT INTO public."schema_migrations" (version) VALUES (20250819030035);
INSERT INTO public."schema_migrations" (version) VALUES (20250819030042);
INSERT INTO public."schema_migrations" (version) VALUES (20250819032032);
INSERT INTO public."schema_migrations" (version) VALUES (20250819032037);
INSERT INTO public."schema_migrations" (version) VALUES (20250819040926);
INSERT INTO public."schema_migrations" (version) VALUES (20250819040930);
INSERT INTO public."schema_migrations" (version) VALUES (20250819040939);
INSERT INTO public."schema_migrations" (version) VALUES (20250819043952);
INSERT INTO public."schema_migrations" (version) VALUES (20250819044605);
INSERT INTO public."schema_migrations" (version) VALUES (20250819211936);
INSERT INTO public."schema_migrations" (version) VALUES (20250819211942);
INSERT INTO public."schema_migrations" (version) VALUES (20250819212328);
INSERT INTO public."schema_migrations" (version) VALUES (20250819213834);
INSERT INTO public."schema_migrations" (version) VALUES (20250820000000);
INSERT INTO public."schema_migrations" (version) VALUES (20250820000001);
INSERT INTO public."schema_migrations" (version) VALUES (20250820000002);
INSERT INTO public."schema_migrations" (version) VALUES (20250820000003);
INSERT INTO public."schema_migrations" (version) VALUES (20250820000004);
INSERT INTO public."schema_migrations" (version) VALUES (20250820000005);
