const STORE_KEY = 'dah.web.v1';
const diffLabels = { easy: 'Fácil', medium: 'Média', hard: 'Difícil', epic: 'Épica' };
const axisLabels = { financeiro: 'Financeiro', saude: 'Saúde', paixoes: 'Paixões' };
const subaxisLabels = { trabalho: 'Trabalho', estudos: 'Estudos', metas: 'Metas', fisica: 'Saúde física', mental: 'Saúde mental', espiritual: 'Espiritualidade', materiais: 'Materiais', criativas: 'Criatividade', lazer: 'Lazer' };
const abilityLabels = { str: 'Força', dex: 'Destreza', con: 'Constituição', int: 'Inteligência', wis: 'Sabedoria', cha: 'Carisma' };
const rewardTypeLabels = { equipamento: 'Equipamento', descanso: 'Descanso', consumivel: 'Consumível', colecionavel: 'Colecionável' };
const difficultyRewards = { easy: [10, 5], medium: [25, 12], hard: [50, 25], epic: [100, 50] };
const seed = {
  mode: 'demo', apiUrl: 'http://localhost:8080', userId: '',
  user: { id: 'demo-user', username: 'Aventureiro', level: 4, xp_atual: 260, xp_total: 860, moedas: 145, atributos_5e: { str: 13, dex: 14, con: 12, int: 16, wis: 11, cha: 10 }, eixos: [
    { eixo: 'financeiro', subeixo: 'estudos', level: 4, xp_atual: 68, xp_total: 368 },
    { eixo: 'financeiro', subeixo: 'trabalho', level: 3, xp_atual: 42, xp_total: 242 },
    { eixo: 'saude', subeixo: 'fisica', level: 2, xp_atual: 55, xp_total: 155 },
    { eixo: 'saude', subeixo: 'mental', level: 2, xp_atual: 20, xp_total: 120 },
    { eixo: 'paixoes', subeixo: 'criativas', level: 1, xp_atual: 77, xp_total: 77 }
  ] },
  quests: [
    { id: 'q1', titulo: 'Estudar um novo capítulo', descricao: 'Avance mais um trecho do livro ou curso que está na sua lista.', dificuldade: 'medium', tipo: 'monster_hunt', eixo_categoria: 'financeiro', subeixo: 'estudos', atributo: 'int', is_daily: true },
    { id: 'q2', titulo: 'Treino de força', descricao: 'Faça uma sessão curta de exercícios e registre como se sentiu.', dificuldade: 'hard', tipo: 'monster_hunt', eixo_categoria: 'saude', subeixo: 'fisica', atributo: 'str', is_daily: false },
    { id: 'q3', titulo: 'Organizar a semana', descricao: 'Escolha três prioridades e reserve tempo para cada uma.', dificuldade: 'easy', tipo: 'questline', eixo_categoria: 'financeiro', subeixo: 'metas', atributo: 'wis', is_daily: true },
    { id: 'q4', titulo: 'Criar por 30 minutos', descricao: 'Separe um tempo sem distrações para praticar algo criativo.', dificuldade: 'medium', tipo: 'monster_hunt', eixo_categoria: 'paixoes', subeixo: 'criativas', atributo: 'cha', is_daily: false }
  ],
  rewards: [
    { id: 'r1', titulo: 'Uma hora de jogo', descricao: 'Uma pausa merecida para jogar sem culpa.', custo_moedas: 45, tipo: 'descanso', stat_key: '', stat_bonus: 0 },
    { id: 'r2', titulo: 'Livro novo', descricao: 'Escolha um livro para alimentar sua próxima aventura.', custo_moedas: 90, tipo: 'equipamento', stat_key: 'int', stat_bonus: 1 },
    { id: 'r3', titulo: 'Café especial', descricao: 'Um pequeno ritual para celebrar o progresso.', custo_moedas: 30, tipo: 'consumivel', stat_key: '', stat_bonus: 0 },
    { id: 'r4', titulo: 'Passeio ao ar livre', descricao: 'Explore um lugar novo e recarregue as energias.', custo_moedas: 60, tipo: 'colecionavel', stat_key: '', stat_bonus: 0 }
  ],
  inventory: []
};
let state = loadState();
let activePage = 'inicio';
let questFilter = 'todas';
let toastTimer;

function loadState() {
  try { return { ...structuredClone(seed), ...JSON.parse(localStorage.getItem(STORE_KEY) || '{}') }; }
  catch { return structuredClone(seed); }
}
function saveState() {
  localStorage.setItem(STORE_KEY, JSON.stringify(state));
  const label = document.querySelector('#save-label'); if (label) label.textContent = 'Progresso salvo';
}
function esc(value = '') { return String(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
function dateLabel() { return new Intl.DateTimeFormat('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date()); }
function initials(name = '') { return name.trim().charAt(0).toUpperCase() || 'A'; }
function showToast(message) {
  const el = document.querySelector('#toast'); el.textContent = message; el.classList.add('show');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => el.classList.remove('show'), 2600);
}
function setPage(page) {
  activePage = page;
  document.querySelectorAll('.page').forEach(el => el.classList.toggle('active-page', el.id === `page-${page}`));
  document.querySelectorAll('.nav-item').forEach(el => el.classList.toggle('active', el.dataset.page === page));
  document.querySelectorAll('.mobile-nav button').forEach(el => el.classList.toggle('active', el.dataset.page === page));
  const names = { inicio: 'Início', quests: 'Quests', loja: 'Loja', configuracoes: 'Configurações' };
  document.querySelector('#page-title').textContent = names[page];
  renderPage(page); window.scrollTo({ top: 0, behavior: 'smooth' });
}
function renderPage(page) {
  if (page === 'inicio') renderDashboard();
  if (page === 'quests') renderQuests();
  if (page === 'loja') renderShop();
  if (page === 'configuracoes') renderSettings();
  document.querySelector('#side-username').textContent = state.user?.username || 'Aventureiro';
  document.querySelector('#avatar-initial').textContent = initials(state.user?.username);
  document.querySelector('#top-avatar').textContent = initials(state.user?.username);
  document.querySelector('#quest-count').textContent = state.quests.length;
}
function xpPercent(user = state.user) { return Math.min(100, Math.max(0, (user.xp_atual || 0) / Math.max(100, user.level * 100) * 100)); }
function renderDashboard() {
  const u = state.user || seed.user, attrs = u.atributos_5e || seed.user.atributos_5e;
  const axes = (u.eixos || []).slice().sort((a, b) => (subaxisLabels[a.subeixo] || a.subeixo).localeCompare(subaxisLabels[b.subeixo] || b.subeixo));
  const iconMap = { estudos: '✧', trabalho: '⌑', fisica: '♧', mental: '☼', metas: '⚑', criativas: '✦', lazer: '☾', espiritual: '◇', materiais: '⬡' };
  document.querySelector('#page-inicio').innerHTML = `
    <div class="welcome-row"><div><div class="eyebrow">BEM-VINDO DE VOLTA, AVENTUREIRO</div><h1>Que sua jornada continue.</h1><p>Cada pequena missão constrói uma grande história.</p></div><div class="date-pill"><span>◷</span>${esc(dateLabel())}</div></div>
    <div class="hero-grid"><article class="hero-card"><span class="hero-symbol">✧</span><div class="eyebrow">O MUNDO ESPERA POR VOCÊ</div><h2>Uma nova missão começa<br>com o próximo passo.</h2><p>Escolha uma quest, siga no seu ritmo e transforme intenção em conquista.</p><button class="button-primary" data-action="goto-quests">Ver minhas quests <span>→</span></button></article>
    <article class="level-card"><div class="level-top"><span class="level-label">PROGRESSO DO AVENTUREIRO</span><span class="level-badge">✦ NÍVEL ${u.level}</span></div><div class="level-main"><span class="level-number">${u.level}</span><div><div class="level-title">Aventureiro</div><div class="level-subtitle">Sua lenda está sendo escrita</div></div></div><div><div class="xp-line"><span>Experiência para o próximo nível</span><strong>${u.xp_atual} / ${u.level * 100} XP</strong></div><div class="progress-track"><div class="progress-fill" style="width:${xpPercent(u)}%"></div></div><div class="xp-note">${Math.max(0, u.level * 100 - u.xp_atual)} XP até o nível ${u.level + 1}</div></div></article></div>
    <div class="stats-strip"><div class="stat-cell"><div class="stat-icon">✧</div><div class="stat-copy"><span>XP acumulado</span><strong>${u.xp_total} <small style="font:10px var(--sans);color:#8e9283">XP</small></strong></div></div><div class="stat-cell"><div class="stat-icon">◈</div><div class="stat-copy"><span>Moedas de ouro</span><strong>${u.moedas}</strong></div></div><div class="stat-cell"><div class="stat-icon">▤</div><div class="stat-copy"><span>Quests ativas</span><strong>${state.quests.length}</strong></div></div><div class="stat-cell"><div class="stat-icon">♜</div><div class="stat-copy"><span>Itens na mochila</span><strong>${state.inventory.length}</strong></div></div></div>
    <div class="dashboard-columns"><section class="panel"><div class="panel-header"><div><div class="panel-title">Quests em andamento</div><span class="panel-subtitle">Pequenas vitórias, grandes jornadas</span></div><button class="text-link" data-action="goto-quests">Ver todas →</button></div><div class="quest-preview-list">${state.quests.length ? state.quests.slice(0, 3).map(q => `<div class="quest-preview"><div class="quest-icon">${q.is_daily ? '☼' : '▤'}</div><div class="quest-preview-copy"><strong>${esc(q.titulo)}</strong><span>${esc(subaxisLabels[q.subeixo] || q.subeixo)} · ${diffLabels[q.dificuldade] || q.dificuldade}</span></div><span class="quest-xp">+${difficultyRewards[q.dificuldade]?.[0] || 0} XP</span></div>`).join('') : '<div class="empty-state">Nenhuma quest ativa. Crie uma missão para começar.</div>'}</div></section>
    <section class="panel attribute-panel"><div class="panel-header"><div><div class="panel-title">Atributos do aventureiro</div><span class="panel-subtitle">Sua ficha de personagem</span></div><span class="tag">D&amp;D 5E</span></div><div class="attribute-grid">${Object.entries(attrs).map(([key, val]) => `<div class="attribute-card"><span>${key.toUpperCase()}</span><strong>${val}</strong><small>${abilityLabels[key] || ''}</small></div>`).join('')}</div><div class="axis-list">${axes.slice(0, 3).map(a => `<div class="axis-row"><div class="axis-icon">${iconMap[a.subeixo] || '✧'}</div><div class="axis-copy"><strong>${esc(subaxisLabels[a.subeixo] || a.subeixo)}</strong><span>${axisLabels[a.eixo] || a.eixo} · ${a.xp_atual} / 100 XP</span></div><span class="axis-level">Nv. ${a.level}</span><div class="axis-progress"><i style="width:${Math.min(100, a.xp_atual)}%"></i></div></div>`).join('')}</div></section></div>`;
}
function renderQuests() {
  const quests = state.quests.filter(q => questFilter === 'todas' || (questFilter === 'diarias' ? q.is_daily : q.dificuldade === questFilter));
  const filterItems = [['todas', 'Todas'], ['diarias', 'Diárias'], ['easy', 'Fáceis'], ['medium', 'Médias'], ['hard', 'Difíceis'], ['epic', 'Épicas']];
  document.querySelector('#page-quests').innerHTML = `<div class="page-heading"><div><div class="eyebrow">SEU DIÁRIO DE AVENTURAS</div><h1>Quests</h1><p>Transforme seus objetivos em missões e avance um passo por vez.</p></div><button class="button-primary" data-action="add-quest">＋ Nova quest</button></div><div class="filter-row">${filterItems.map(([id, label]) => `<button class="filter-chip ${questFilter === id ? 'active' : ''}" data-filter="${id}">${label}</button>`).join('')}<span class="result-count">${quests.length} ${quests.length === 1 ? 'missão' : 'missões'}</span></div><div class="quest-grid">${quests.length ? quests.map(questCard).join('') : '<div class="panel empty-state" style="grid-column:1/-1">Nenhuma missão por aqui. Que tal criar sua próxima quest?</div>'}</div>`;
}
function questCard(q) {
  const [xp, coins] = difficultyRewards[q.dificuldade] || [0, 0];
  return `<article class="quest-card"><div class="card-topline"><span class="tag ${q.is_daily ? 'daily' : ''}">${q.is_daily ? '☼ Quest diária' : (q.tipo === 'questline' ? '⌁ Linha de missão' : '▤ Caça a monstro')}</span><span class="difficulty ${q.dificuldade}">${diffLabels[q.dificuldade] || q.dificuldade}</span></div><h3>${esc(q.titulo)}</h3><p>${esc(q.descricao)}</p><div class="quest-meta"><span class="meta-chip">${esc(axisLabels[q.eixo_categoria] || q.eixo_categoria)}</span><span class="meta-chip">${esc(subaxisLabels[q.subeixo] || q.subeixo)}</span><span class="meta-chip">${esc((q.atributo || '').toUpperCase())} · ${esc(abilityLabels[q.atributo] || '')}</span></div><div class="quest-bottom"><div class="reward-pair"><span>✧ +${xp} XP</span><span>◈ +${coins} moedas</span></div><div class="quest-actions"><button class="complete-button" data-action="complete-quest" data-id="${esc(q.id)}">Concluir ✓</button></div></div></article>`;
}
function renderShop() {
  const symbols = { equipamento: '⚔', descanso: '☾', consumivel: '⚗', colecionavel: '✦' };
  document.querySelector('#page-loja').innerHTML = `<div class="page-heading"><div><div class="eyebrow">RECOMPENSE SUA DEDICAÇÃO</div><h1>Loja do aventureiro</h1><p>Troque suas moedas por recompensas que deixam a jornada mais leve.</p></div><div class="date-pill"><span>◈</span>${state.user.moedas} moedas</div></div><div class="shop-grid">${state.rewards.length ? state.rewards.map(r => `<article class="shop-card"><div class="shop-symbol">${symbols[r.tipo] || '✦'}</div><h3>${esc(r.titulo)}</h3><p>${esc(r.descricao)}</p><div class="shop-type">${rewardTypeLabels[r.tipo] || r.tipo}${r.stat_key && r.stat_bonus ? ` · +${r.stat_bonus} ${r.stat_key.toUpperCase()}` : ''}</div><div class="shop-bottom"><span class="price">◈ ${r.custo_moedas}<small>moedas</small></span><button class="button-primary" data-action="buy-reward" data-id="${esc(r.id)}" ${state.user.moedas < r.custo_moedas ? 'disabled' : ''}>${state.user.moedas < r.custo_moedas ? 'Saldo insuficiente' : 'Resgatar →'}</button></div></article>`).join('') : '<div class="panel empty-state" style="grid-column:1/-1">A loja está vazia por enquanto. Adicione recompensas nas configurações da demonstração.</div>'}</div>`;
}
function renderSettings() {
  document.querySelector('#page-configuracoes').innerHTML = `<div class="page-heading"><div><div class="eyebrow">AJUSTE A SUA EXPERIÊNCIA</div><h1>Configurações</h1><p>Personalize seu perfil ou conecte a demonstração ao servidor.</p></div></div><div class="settings-layout"><nav class="settings-nav"><button class="active" data-settings-tab="conexao">◉ Conexão</button><button data-settings-tab="perfil">♙ Perfil</button><button data-settings-tab="dados">▤ Dados da demo</button></nav><div class="panel settings-panel" id="settings-content"></div></div>`;
  renderSettingsTab('conexao');
}
function renderSettingsTab(tab) {
  document.querySelectorAll('[data-settings-tab]').forEach(el => el.classList.toggle('active', el.dataset.settingsTab === tab));
  const root = document.querySelector('#settings-content');
  if (tab === 'conexao') root.innerHTML = `<h2>Modo de validação</h2><p>Use os dados locais para explorar o produto ou conecte sua API Go.</p><div class="mode-row"><div class="mode-copy"><strong>Demonstração local</strong><span>Dados salvos neste navegador. Funciona sem servidor.</span></div><button class="toggle ${state.mode === 'demo' ? 'on' : ''}" data-action="mode-demo" aria-label="Ativar demonstração"><i></i></button></div><div class="mode-row"><div class="mode-copy"><strong>API do projeto</strong><span>Sincroniza ficha, quests e loja com o backend.</span></div><button class="toggle ${state.mode === 'api' ? 'on' : ''}" data-action="mode-api" aria-label="Ativar API"><i></i></button></div><label class="form-label" for="api-url">URL base da API</label><input class="form-input" id="api-url" value="${esc(state.apiUrl)}" placeholder="http://localhost:8080"><label class="form-label" for="user-id">ID do usuário</label><input class="form-input" id="user-id" value="${esc(state.userId)}" placeholder="UUID retornado ao criar usuário"><div class="form-hint">Para usar a API no navegador, inicie o servidor e abra este app por um servidor local (por exemplo: <code>python3 -m http.server 5500</code>). A API precisa permitir requisições CORS da origem local.</div><div class="form-actions"><button class="button-primary" data-action="save-connection">Salvar e sincronizar</button><button class="button-quiet" data-action="refresh">Sincronizar agora</button></div><hr class="settings-divider"><div class="mode-copy"><strong>Estado atual: ${state.mode === 'demo' ? 'Demonstração local' : 'API'}</strong><span>${state.mode === 'demo' ? 'Suas ações ficam salvas no navegador.' : 'A ficha e as listas serão carregadas do servidor.'}</span></div>`;
  if (tab === 'perfil') root.innerHTML = `<h2>Ficha do aventureiro</h2><p>Este nome aparece no cabeçalho e na ficha.</p><label class="form-label" for="username">Nome de aventureiro</label><input class="form-input" id="username" value="${esc(state.user.username)}" maxlength="32"><div class="form-hint">Na demo, o progresso fica neste navegador. No modo API, a ficha é criada pelo endpoint de usuários.</div><div class="form-actions"><button class="button-primary" data-action="save-profile">Salvar nome</button><button class="button-secondary" data-action="create-user">Criar usuário na API</button></div>`;
  if (tab === 'dados') root.innerHTML = `<h2>Dados para validação</h2><p>Edite o conteúdo de demonstração para experimentar diferentes estados do produto.</p><div class="mode-row"><div class="mode-copy"><strong>${state.quests.length} quests pendentes</strong><span>Adicione, conclua ou reinicie sua lista.</span></div><button class="button-secondary" data-action="add-quest">＋ Nova quest</button></div><div class="mode-row"><div class="mode-copy"><strong>${state.rewards.length} recompensas na loja</strong><span>Teste preços, bônus e saldo insuficiente.</span></div><button class="button-secondary" data-action="add-reward">＋ Nova recompensa</button></div><div class="mode-row"><div class="mode-copy"><strong>${state.inventory.length} itens resgatados</strong><span>As compras feitas na demo aparecem aqui.</span></div><span class="tag">${state.inventory.length} itens</span></div><div class="form-actions"><button class="button-quiet" data-action="reset-demo">Restaurar dados iniciais da demo</button></div>`;
}

function openQuestModal() {
  document.querySelector('#modal-root').innerHTML = `<div class="modal-backdrop" data-action="close-modal"><form class="modal" id="quest-form"><div class="modal-head"><div><div class="eyebrow">ADICIONE UM NOVO DESAFIO</div><h2>Nova quest</h2></div><button type="button" class="modal-close" data-action="close-modal">×</button></div><div class="form-grid"><div class="span-two"><label class="form-label">Título</label><input class="form-input" name="title" required maxlength="160" placeholder="Ex.: Caminhar por 20 minutos"></div><div class="span-two"><label class="form-label">Descrição</label><textarea class="form-textarea" name="description" maxlength="2000" placeholder="O que você vai fazer para concluir?" required></textarea></div><div><label class="form-label">Dificuldade</label><select class="form-select" name="difficulty"><option value="easy">Fácil · 10 XP</option><option value="medium" selected>Média · 25 XP</option><option value="hard">Difícil · 50 XP</option><option value="epic">Épica · 100 XP</option></select></div><div><label class="form-label">Tipo</label><select class="form-select" name="kind"><option value="monster_hunt">Caça a monstro</option><option value="questline">Linha de missão</option></select></div><div><label class="form-label">Eixo</label><select class="form-select" name="axis"><option value="financeiro">Financeiro</option><option value="saude">Saúde</option><option value="paixoes">Paixões</option></select></div><div><label class="form-label">Subeixo</label><select class="form-select" name="subaxis"></select></div><div><label class="form-label">Atributo</label><select class="form-select" name="ability">${Object.entries(abilityLabels).map(([k,v])=>`<option value="${k}">${k.toUpperCase()} · ${v}</option>`).join('')}</select></div><div class="span-two"><label class="check-row"><input type="checkbox" name="daily"> Quest diária</label></div></div><div class="modal-actions"><button type="button" class="button-quiet" data-action="close-modal">Cancelar</button><button class="button-primary" type="submit">Criar quest</button></div></form></div>`;
  const form = document.querySelector('#quest-form'); const axis = form.elements.axis; const sub = form.elements.subaxis;
  const updateSub = () => { const pairs = { financeiro: ['trabalho','estudos','metas'], saude: ['fisica','mental','espiritual'], paixoes: ['materiais','criativas','lazer'] }; sub.innerHTML = pairs[axis.value].map(k=>`<option value="${k}">${subaxisLabels[k]}</option>`).join(''); };
  axis.addEventListener('change', updateSub); updateSub();
}
function openRewardModal() {
  document.querySelector('#modal-root').innerHTML = `<div class="modal-backdrop" data-action="close-modal"><form class="modal" id="reward-form"><div class="modal-head"><div><div class="eyebrow">CRIE UMA RECOMPENSA</div><h2>Item para a loja</h2></div><button type="button" class="modal-close" data-action="close-modal">×</button></div><div class="form-grid"><div class="span-two"><label class="form-label">Nome da recompensa</label><input class="form-input" name="title" required maxlength="160" placeholder="Ex.: Uma tarde de descanso"></div><div class="span-two"><label class="form-label">Descrição</label><textarea class="form-textarea" name="description" required maxlength="2000" placeholder="Descreva a recompensa"></textarea></div><div><label class="form-label">Custo em moedas</label><input class="form-input" name="cost" type="number" min="0" max="1000000" value="50" required></div><div><label class="form-label">Categoria</label><select class="form-select" name="kind">${Object.entries(rewardTypeLabels).map(([k,v])=>`<option value="${k}">${v}</option>`).join('')}</select></div><div><label class="form-label">Bônus de atributo (opcional)</label><select class="form-select" name="stat"><option value="">Sem bônus</option>${Object.keys(abilityLabels).map(k=>`<option value="${k}">+1 ${k.toUpperCase()}</option>`).join('')}</select></div></div><div class="modal-actions"><button type="button" class="button-quiet" data-action="close-modal">Cancelar</button><button class="button-primary" type="submit">Adicionar à loja</button></div></form></div>`;
}

function completeQuest(id) {
  if (state.mode === 'api') return apiAction(`/quests/${encodeURIComponent(id)}/complete`, { method: 'POST' }).then(result => {
    state.quests = state.quests.filter(q => q.id !== id);
    if (result) { Object.assign(state.user, { xp_atual: result.xp_atual, xp_total: result.xp_total, level: result.level, moedas: result.moedas, atributos_5e: result.atributos_5e }); const axes = state.user.eixos || []; state.user.eixos = axes.filter(a => a.subeixo !== result.progresso_eixo?.subeixo).concat(result.progresso_eixo ? [result.progresso_eixo] : []); }
    saveState(); renderAll(); showToast(`Quest concluída! +${result?.xp_ganho ?? 'XP'} XP e moedas recebidas.`);
  });
  const q = state.quests.find(x => x.id === id); if (!q) return;
  const [xp, coins] = difficultyRewards[q.dificuldade]; state.quests = state.quests.filter(x => x.id !== id);
  state.user.xp_atual += xp; state.user.xp_total += xp; state.user.moedas += coins;
  while (state.user.xp_atual >= state.user.level * 100) { state.user.xp_atual -= state.user.level * 100; state.user.level++; }
  const axis = state.user.eixos.find(a => a.subeixo === q.subeixo);
  if (axis) { axis.xp_atual += xp; axis.xp_total += xp; while (axis.xp_atual >= 100) { axis.xp_atual -= 100; axis.level++; } }
  const attr = q.atributo; if (state.user.atributos_5e[attr] !== undefined) state.user.atributos_5e[attr] = Math.min(30, state.user.atributos_5e[attr] + Math.floor(xp / 100));
  saveState(); renderAll(); showToast(`Quest concluída! +${xp} XP · +${coins} moedas`);
}
function buyReward(id) {
  const reward = state.rewards.find(r => r.id === id); if (!reward) return;
  if (state.mode === 'api') return apiAction(`/rewards/${encodeURIComponent(id)}/buy`, { method: 'POST', body: JSON.stringify({ user_id: state.userId }) }).then(result => { state.user.moedas = result.moedas_restantes ?? result.remaining_coins ?? result.moedas ?? state.user.moedas - reward.custo_moedas; state.inventory.push({ ...reward, purchased_at: new Date().toISOString() }); saveState(); renderAll(); showToast(`${reward.titulo} resgatado!`); });
  if (state.user.moedas < reward.custo_moedas) return showToast('Você ainda não tem moedas suficientes.');
  state.user.moedas -= reward.custo_moedas; state.inventory.push({ ...reward, purchased_at: new Date().toISOString() });
  if (reward.stat_key && reward.stat_bonus) state.user.atributos_5e[reward.stat_key] = Math.min(30, state.user.atributos_5e[reward.stat_key] + reward.stat_bonus);
  saveState(); renderAll(); showToast(`${reward.titulo} resgatado!`);
}
function addQuestFromForm(form) {
  const v = new FormData(form); const q = { id: crypto.randomUUID(), titulo: v.get('title').trim(), descricao: v.get('description').trim(), dificuldade: v.get('difficulty'), tipo: v.get('kind'), eixo_categoria: v.get('axis'), subeixo: v.get('subaxis'), atributo: v.get('ability'), is_daily: v.has('daily') };
  if (state.mode === 'api') return apiAction('/quests', { method: 'POST', body: JSON.stringify({ user_id: state.userId, title: q.titulo, description: q.descricao, difficulty: q.dificuldade, type: q.tipo, axis_category: q.eixo_categoria, subaxis: q.subeixo, ability_key: q.atributo, is_daily: q.is_daily }) }).then(created => { state.quests.unshift(created); saveState(); closeModal(); renderAll(); showToast('Quest adicionada à sua jornada.'); });
  state.quests.unshift(q); saveState(); closeModal(); renderAll(); showToast('Quest adicionada à sua jornada.');
}
function addRewardFromForm(form) {
  const v = new FormData(form); const reward = { id: crypto.randomUUID(), titulo: v.get('title').trim(), descricao: v.get('description').trim(), custo_moedas: Number(v.get('cost')), tipo: v.get('kind'), stat_key: v.get('stat'), stat_bonus: v.get('stat') ? 1 : 0 };
  if (state.mode === 'api') return apiAction('/rewards', { method: 'POST', body: JSON.stringify({ user_id: state.userId, title: reward.titulo, description: reward.descricao, cost: reward.custo_moedas, type: reward.tipo, stat_key: reward.stat_key, stat_bonus: reward.stat_bonus }) }).then(created => { state.rewards.unshift(created); saveState(); closeModal(); renderAll(); showToast('Recompensa adicionada à loja.'); });
  state.rewards.unshift(reward); saveState(); closeModal(); renderAll(); showToast('Recompensa adicionada à loja.');
}
function closeModal() { document.querySelector('#modal-root').innerHTML = ''; }
function renderAll() { renderPage(activePage); }
async function apiRequest(path, options = {}) {
  const base = state.apiUrl.replace(/\/+$/, ''); const resp = await fetch(`${base}${path}`, { ...options, headers: { 'Content-Type': 'application/json', ...(options.headers || {}) } });
  const data = await resp.json().catch(() => ({})); if (!resp.ok) throw new Error(data.error || `Erro HTTP ${resp.status}`); return data;
}
async function apiAction(path, options = {}) { try { return await apiRequest(path, options); } catch (err) { showToast(`Falha na API: ${err.message}`); throw err; } }
async function syncFromApi() {
  if (!state.userId) throw new Error('Informe o ID do usuário na aba Configurações.');
  const [user, quests, rewards] = await Promise.all([apiRequest(`/user/${encodeURIComponent(state.userId)}/sheet`), apiRequest(`/quests?user_id=${encodeURIComponent(state.userId)}`), apiRequest(`/rewards?user_id=${encodeURIComponent(state.userId)}`)]);
  state.user = user; state.quests = quests || []; state.rewards = rewards || []; saveState(); renderAll(); showToast('Dados sincronizados com a API.');
}

document.addEventListener('click', async event => {
  const nav = event.target.closest('[data-page]'); if (nav) return setPage(nav.dataset.page);
  const filter = event.target.closest('[data-filter]'); if (filter) { questFilter = filter.dataset.filter; return renderQuests(); }
  const tab = event.target.closest('[data-settings-tab]'); if (tab) return renderSettingsTab(tab.dataset.settingsTab);
  const action = event.target.closest('[data-action]'); if (!action) return;
  const id = action.dataset.id;
  try {
    switch (action.dataset.action) {
      case 'goto-quests': setPage('quests'); break;
      case 'add-quest': openQuestModal(); break;
      case 'add-reward': openRewardModal(); break;
      case 'close-modal': if (event.target === action || action.classList.contains('modal-close')) closeModal(); break;
      case 'complete-quest': await completeQuest(id); break;
      case 'buy-reward': await buyReward(id); break;
      case 'mode-demo': state.mode = 'demo'; saveState(); renderSettingsTab('conexao'); showToast('Demonstração local ativada.'); break;
      case 'mode-api': state.mode = 'api'; saveState(); renderSettingsTab('conexao'); showToast('Modo API selecionado.'); break;
      case 'save-connection': state.apiUrl = document.querySelector('#api-url').value.trim().replace(/\/+$/, ''); state.userId = document.querySelector('#user-id').value.trim(); state.mode = 'api'; saveState(); await syncFromApi(); break;
      case 'refresh': if (state.mode === 'api') await syncFromApi(); else showToast('A demonstração está atualizada.'); break;
      case 'save-profile': { const name = document.querySelector('#username').value.trim(); if (!/^[A-Za-z0-9_]{3,32}$/.test(name)) return showToast('Use 3 a 32 caracteres: letras, números ou underscore.'); state.user.username = name; saveState(); renderAll(); showToast('Perfil atualizado.'); break; }
      case 'create-user': { const name = document.querySelector('#username').value.trim(); if (!/^[A-Za-z0-9_]{3,32}$/.test(name)) return showToast('Use 3 a 32 caracteres: letras, números ou underscore.'); const created = await apiRequest('/users', { method: 'POST', body: JSON.stringify({ username: name }) }); state.userId = created.id; state.user = created; state.mode = 'api'; saveState(); await syncFromApi(); renderSettingsTab('perfil'); showToast('Usuário criado e conectado.'); break; }
      case 'reset-demo': if (confirm('Restaurar os dados iniciais? Seu progresso de demonstração atual será apagado.')) { state = structuredClone(seed); saveState(); renderAll(); renderSettingsTab('dados'); showToast('Demonstração restaurada.'); } break;
    }
  } catch (err) { console.error(err); showToast(err.message || 'Não foi possível concluir a ação.'); }
});
document.addEventListener('submit', async event => {
  if (event.target.id === 'quest-form') { event.preventDefault(); try { await addQuestFromForm(event.target); } catch {} }
  if (event.target.id === 'reward-form') { event.preventDefault(); try { await addRewardFromForm(event.target); } catch {} }
});
document.querySelector('#refresh-button').addEventListener('click', async () => { try { if (state.mode === 'api') await syncFromApi(); else showToast('A demonstração está atualizada.'); } catch (err) { showToast(err.message); } });
document.body.insertAdjacentHTML('beforeend', `<nav class="mobile-nav">${[['inicio','⌂','Início'],['quests','▤','Quests'],['loja','◇','Loja'],['configuracoes','⚙','Ajustes']].map(([p,i,l])=>`<button data-page="${p}" class="${p==='inicio'?'active':''}"><span>${i}</span>${l}</button>`).join('')}</nav>`);
renderAll();
