-- Dungeons and Habits starter schema for PostgreSQL.

CREATE TABLE users (
    id UUID PRIMARY KEY,
    username VARCHAR(32) NOT NULL,
    xp_atual INTEGER NOT NULL DEFAULT 0 CHECK (xp_atual >= 0),
    xp_total BIGINT NOT NULL DEFAULT 0 CHECK (xp_total >= 0),
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    moedas BIGINT NOT NULL DEFAULT 0 CHECK (moedas >= 0),
    role VARCHAR(16) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),

    str SMALLINT NOT NULL DEFAULT 10 CHECK (str BETWEEN 1 AND 30),
    dex SMALLINT NOT NULL DEFAULT 10 CHECK (dex BETWEEN 1 AND 30),
    con SMALLINT NOT NULL DEFAULT 10 CHECK (con BETWEEN 1 AND 30),
    "int" SMALLINT NOT NULL DEFAULT 10 CHECK ("int" BETWEEN 1 AND 30),
    wis SMALLINT NOT NULL DEFAULT 10 CHECK (wis BETWEEN 1 AND 30),
    cha SMALLINT NOT NULL DEFAULT 10 CHECK (cha BETWEEN 1 AND 30),

    str_xp INTEGER NOT NULL DEFAULT 0 CHECK (str_xp BETWEEN 0 AND 99),
    dex_xp INTEGER NOT NULL DEFAULT 0 CHECK (dex_xp BETWEEN 0 AND 99),
    con_xp INTEGER NOT NULL DEFAULT 0 CHECK (con_xp BETWEEN 0 AND 99),
    int_xp INTEGER NOT NULL DEFAULT 0 CHECK (int_xp BETWEEN 0 AND 99),
    wis_xp INTEGER NOT NULL DEFAULT 0 CHECK (wis_xp BETWEEN 0 AND 99),
    cha_xp INTEGER NOT NULL DEFAULT 0 CHECK (cha_xp BETWEEN 0 AND 99),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (username ~ '^[A-Za-z0-9_]{3,32}$')
);

CREATE UNIQUE INDEX users_username_ci_uq ON users (lower(username));

CREATE TABLE user_axis_progress (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    axis_category VARCHAR(16) NOT NULL CHECK (axis_category IN ('financeiro', 'saude', 'paixoes')),
    subaxis VARCHAR(16) NOT NULL CHECK (
        subaxis IN ('trabalho', 'estudos', 'metas', 'fisica', 'mental', 'espiritual', 'materiais', 'criativas', 'lazer')
    ),
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    xp_atual INTEGER NOT NULL DEFAULT 0 CHECK (xp_atual BETWEEN 0 AND 99),
    xp_total BIGINT NOT NULL DEFAULT 0 CHECK (xp_total >= 0),
    PRIMARY KEY (user_id, subaxis),
    CHECK (
        (axis_category = 'financeiro' AND subaxis IN ('trabalho', 'estudos', 'metas')) OR
        (axis_category = 'saude' AND subaxis IN ('fisica', 'mental', 'espiritual')) OR
        (axis_category = 'paixoes' AND subaxis IN ('materiais', 'criativas', 'lazer'))
    )
);

CREATE TABLE quests (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    titulo VARCHAR(160) NOT NULL,
    descricao VARCHAR(2000) NOT NULL DEFAULT '',
    dificuldade VARCHAR(16) NOT NULL CHECK (dificuldade IN ('easy', 'medium', 'hard', 'epic')),
    status VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    tipo VARCHAR(24) NOT NULL CHECK (tipo IN ('monster_hunt', 'questline')),
    eixo_categoria VARCHAR(16) NOT NULL CHECK (eixo_categoria IN ('financeiro', 'saude', 'paixoes')),
    subeixo VARCHAR(16) NOT NULL CHECK (
        subeixo IN ('trabalho', 'estudos', 'metas', 'fisica', 'mental', 'espiritual', 'materiais', 'criativas', 'lazer')
    ),
    atributo VARCHAR(3) NOT NULL CHECK (atributo IN ('str', 'dex', 'con', 'int', 'wis', 'cha')),
    is_daily BOOLEAN NOT NULL DEFAULT false,
    due_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    CHECK (
        (eixo_categoria = 'financeiro' AND subeixo IN ('trabalho', 'estudos', 'metas')) OR
        (eixo_categoria = 'saude' AND subeixo IN ('fisica', 'mental', 'espiritual')) OR
        (eixo_categoria = 'paixoes' AND subeixo IN ('materiais', 'criativas', 'lazer'))
    ),
    CHECK ((status = 'pending' AND completed_at IS NULL) OR (status = 'completed' AND completed_at IS NOT NULL))
);

CREATE INDEX quests_pending_by_user_idx
    ON quests (user_id, due_at NULLS LAST, created_at DESC)
    WHERE status = 'pending';

CREATE TABLE rewards (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    titulo VARCHAR(160) NOT NULL,
    descricao VARCHAR(2000) NOT NULL DEFAULT '',
    custo_moedas BIGINT NOT NULL CHECK (custo_moedas >= 0),
    tipo VARCHAR(24) NOT NULL CHECK (tipo IN ('equipamento', 'descanso', 'consumivel', 'colecionavel')),
    stat_key VARCHAR(3) CHECK (stat_key IN ('str', 'dex', 'con', 'int', 'wis', 'cha')),
    stat_bonus SMALLINT NOT NULL DEFAULT 0 CHECK (stat_bonus BETWEEN 0 AND 10),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (stat_bonus = 0 OR (tipo = 'equipamento' AND stat_key IS NOT NULL))
);

CREATE INDEX rewards_by_user_idx ON rewards (user_id, created_at DESC);

CREATE TABLE user_inventory (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_id UUID NOT NULL REFERENCES rewards(id),
    quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    PRIMARY KEY (user_id, reward_id)
);

CREATE TABLE reward_purchases (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_id UUID NOT NULL REFERENCES rewards(id),
    cost_paid BIGINT NOT NULL CHECK (cost_paid >= 0),
    title_snapshot VARCHAR(160) NOT NULL,
    tipo_snapshot VARCHAR(24) NOT NULL,
    stat_key_snapshot VARCHAR(3),
    stat_bonus_snapshot SMALLINT NOT NULL DEFAULT 0,
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX reward_purchases_by_user_idx ON reward_purchases (user_id, purchased_at DESC);

-- TODO: modelar NPCs gerados proceduralmente e sua relação com questlines.
