#!/bin/bash

# 
# cat 명령어와 EOF 사이에 Database 초기화 스크립트를 넣어두면 된다.
#
cat << EOF
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT exists vector;


DROP TABLE IF EXISTS public.answer_by_reference_synapse;
DROP TABLE IF EXISTS public.sessions_details_synapse;
DROP TABLE IF EXISTS public.user_messages_synapse;

DROP TABLE IF EXISTS public.langchain_pg_embedding;
DROP table IF EXISTS public.langchain_pg_collection;


CREATE TABLE public.langchain_pg_collection (
    uuid uuid NOT NULL,
    name character varying,
    cmetadata json,
    PRIMARY KEY (uuid)
);
ALTER TABLE public.langchain_pg_collection OWNER TO "${SERVICE_VS_USER}";


CREATE TABLE public.langchain_pg_embedding (
    uuid uuid NOT NULL,
    collection_id uuid,
    embedding public.vector,
    document character varying,
    cmetadata jsonb,
    custom_id character varying,
    PRIMARY KEY (uuid),
    FOREIGN KEY(collection_id) REFERENCES langchain_pg_collection (uuid) ON DELETE CASCADE
);
ALTER TABLE public.langchain_pg_embedding OWNER TO "${SERVICE_VS_USER}";

CREATE TABLE public.user_messages_synapse (
    user_id character varying NOT NULL,
    "time" timestamp without time zone,
    status integer,
    content text,
    PRIMARY KEY(user_id)
);
ALTER TABLE public.user_messages_synapse OWNER TO "${SERVICE_VS_USER}";


CREATE TABLE public.sessions_details_synapse (
    answer_id uuid NOT NULL,
    user_id character varying NOT NULL,
    "time" timestamp without time zone,
    question text,
    answer text,
    "like" boolean,
    dislike boolean,
    PRIMARY KEY(answer_id),
    FOREIGN KEY(user_id) REFERENCES user_messages_synapse (user_id) ON DELETE CASCADE
);
ALTER TABLE public.sessions_details_synapse OWNER TO "${SERVICE_VS_USER}";

CREATE TABLE public.answer_by_reference_synapse (
    answer_id uuid NOT NULL,
    doc_id uuid NOT NULL,
    FOREIGN KEY(answer_id) REFERENCES sessions_details_synapse (answer_id) ON DELETE cascade,
    FOREIGN KEY(doc_id) REFERENCES langchain_pg_embedding (uuid) ON DELETE CASCADE
);
ALTER TABLE public.answer_by_reference_synapse OWNER TO "${SERVICE_VS_USER}";

alter table answer_by_reference_synapse add score float not null;
alter table langchain_pg_embedding add url varchar(1000);

DROP TABLE IF EXISTS public.customer;
DROP TABLE IF EXISTS public.service;
DROP TABLE IF EXISTS public.service_configuration;
DROP TABLE IF EXISTS public.reference_knowledge;
DROP TABLE IF EXISTS public.answer;
DROP TABLE IF EXISTS public.knowledge_set;
DROP TABLE IF EXISTS public.session;
DROP TABLE IF EXISTS public.knowledge_source;
drop table if exists public.chatbot_info;

create table public.customer (
   id                  uuid primary key,
   "name"           varchar(256),
   email		varchar(256),
   "password"	varchar(256),
   update_at	timestamp,
   create_at	        timestamp
);
ALTER TABLE public.customer OWNER TO "${SERVICE_VS_USER}";

create table public.service (
    id                 uuid primary key,
    customer_id        uuid,       -- FK customer.id
    "name"             varchar(256),
    description        varchar(4000),
    api_key            varchar(128),
    model              varchar(128),                      -- LLM Service or model name
    model_api_key      varchar(128),
    embeddings         varchar(128),                       -- Embedding Service or model name
    embeddings_api_key varchar(128),
    status   int,                           -- Available 0 , Disable 1, Error 999
   update_at	timestamp,
   create_at	        timestamp
);
ALTER TABLE public.service OWNER TO "${SERVICE_VS_USER}";

create table public.service_configuration (
    service_id uuid,
    "key"      varchar(256),
    "value"    varchar(256),
    primary key (service_id, key)
);
ALTER TABLE public.service_configuration OWNER TO "${SERVICE_VS_USER}";

create table public.session (
    id            uuid primary key,
    customer_id   uuid,         -- FK customer.id
    service_id    uuid,         -- FK service.id
    channel_type  varchar(64),  -- CHATBOT/KAKAOTALK/...
    user_name     varchar(256),
    started_at    timestamp,
    ended_at     timestamp
);
ALTER TABLE public.session OWNER TO "${SERVICE_VS_USER}";

create table public.answer (
    id             SERIAL primary key,
    session_id     uuid,          -- FK session 
    question       varchar(4000),
    response       varchar(4000),
    user_feedback  int,           -- 부정평가 <0, 중립(없음) == 0, 긍정평가 > 0
    admin_feedback int,           -- 부정평가 <0, 중립(없음) == 0, 긍정평가 > 0
    status         int,            -- INIT, 확인, 점검필, 조치완료
    started_at    timestamp,
    ended_at     timestamp,
    response_time int
);
ALTER TABLE public.answer OWNER TO "${SERVICE_VS_USER}";

create table public.chatbot_info (
    id SERIAL primary key,
    service_id uuid, -- service table id
    summary_llm varchar(256),
    welcome_message varchar(4096),
    background varchar(256), --background_color
    customer_icon varchar(256),
    customer_background_color varchar(256),-- icon, background_color, text_color
    custormer_text_color varchar(256),
    bot_icon varchar(256),
    bot_background_color varchar(256),-- icon, background_color, text_color
    bot_text_color varchar(256),
    width varchar(256),
    height varchar(256)
);
ALTER TABLE public.chatbot_info OWNER TO "${SERVICE_VS_USER}";

CREATE INDEX customer_id_index ON langchain_pg_collection((cmetadata->>'customer_id'));
CREATE INDEX service_id_index ON langchain_pg_collection((cmetadata->>'service_id'));
CREATE INDEX customer_service_id_index ON langchain_pg_collection((cmetadata->>'customer_id'), (cmetadata->>'service_id'));
CREATE INDEX source_index ON langchain_pg_embedding((cmetadata->>'source'));
CREATE INDEX file_id_index ON langchain_pg_embedding((cmetadata->>'file_id'));
CREATE INDEX seq_num_index ON langchain_pg_embedding((cmetadata->>'seq_num'));

create table public.reference_knowledge (
    answer_id int, -- FK answer.id
    knowledge_set_id int, -- knowledge_set.id
    collection_id uuid, -- langchain_pg_collection.uuid not FK
    embedding_id uuid, -- langchain_pg_embedding.uuid
    similarity float, -- Retr. 결과로 올라온 유사
    score int, -- 화면에 보여주기 위해 normalize한 유사
    "document" varchar(4000), -- 답변시점의 근거 문서
    status int -- INIT, 확인, 점검필, 조치완료
);
ALTER TABLE public.reference_knowledge OWNER TO "${SERVICE_VS_USER}";

create table public.knowledge_source (
    id SERIAL primary key,
    knowledge_set_id int, -- int로 값 변경 (0620 정연우)
    source_type int, -- 0:수동추가/1: File/2: Database/3~: 추후 확장
    name varchar(256),
    status int, -- 완료 0, 실패 999, chunking 1, embedding 2
    metadata json, -- 일단은 {}로 채울 수 있는지 확인해서 가능하다면 빈 JSON Object로 채웁시다.
    created_at timestamp
);
ALTER TABLE public.knowledge_source OWNER TO "${SERVICE_VS_USER}";

create table public.knowledge_set (
    id SERIAL primary key,
    customer_id uuid, -- FK customer.id
    service_id uuid, -- FK service.id
    collection_id uuid, -- FK langchain_pg_collection."uuid"
    "name" varchar(256),
    description varchar(4000),
    update_at timestamp,
    create_at timestamp
);
ALTER TABLE public.knowledge_set OWNER TO "${SERVICE_VS_USER}";

create table public.task (
    task_id SERIAL primary key,
    start timestamp,
    "end" timestamp,
    status varchar(256),
    result json,
    progress json
);
ALTER TABLE public.task OWNER TO "${SERVICE_VS_USER}";


DROP TABLE IF EXISTS public.customer_balance;
DROP TABLE IF EXISTS public.customer_transaction;

create table public.customer_balance (
	id 			SERIAL primary key,
	customer_id 	uuid,
	balance 		int,
	update_at timestamp,
	create_at timestamp
);
ALTER TABLE public.customer_balance OWNER TO "${SERVICE_VS_USER}";

create table public.customer_transaction (
	id 			SERIAL primary key,
	customer_id 	uuid,
	type 			varchar(256),
	amount 		int,
	description		varchar(256),
	create_at timestamp
);
ALTER TABLE public.customer_balance OWNER TO "${SERVICE_VS_USER}";

EOF
