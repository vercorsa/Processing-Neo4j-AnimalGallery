import java.net.*;
import java.io.*;
import java.util.*;
import java.util.Base64;

// =====================================================
// LISTAS
// =====================================================
ArrayList<AnimalItem> todos = new ArrayList<AnimalItem>();
ArrayList<AnimalItem> visiveis = new ArrayList<AnimalItem>();

// =====================================================
// NEO4J (HTTP)
// =====================================================
String NEO4J_URL  = "http://localhost:7474/db/neo4j/tx/commit";
String NEO4J_USER = "neo4j";
String NEO4J_PASS = "neo4j1234";

String neo4jStatus = "Neo4j: a carregar...";

// =====================================================
// TEXTURAS (SALA)
// =====================================================
PImage texChao, texParede, texTecto;

// dimensões da sala
float salaW = 1200;
float salaD = 1400;
float salaH = 520;

// =====================================================
// PAREDE DO MEIO (MENOR) + QUADROS
// =====================================================
boolean usarParedeMeio = true;
float meioZ = 0;
float meioEspessura = 26;

// tamanho da parede menor
float meioW = 760;
float meioH = 360;
float meioYBase = 80; // começa um pouco acima do chão

// quantos quadros vão na vitrine (frente e trás)
int meioMaxFrente = 8;
int meioMaxTras   = 8;

// =====================================================
// CAMERA FPS (NO CHAO, SEM VOAR)
// =====================================================
float camX = 0;
float camY = 180;     // altura fixa
float camZ = 520;

float yaw = 0;        // esquerda/direita
float pitch = 0;      // cima/baixo (só para olhar)
float mouseSens = 0.010;

boolean wDown, aDown, sDown, dDown, shiftDown;

// --- COLISÃO ---
float playerRadius = 45;
float wallPadding  = 8;

// =====================================================
// FILTROS
// =====================================================
String filtroTipo = "todos";      // "todos" | "cão" | "gato" | "vaca"
String filtroSexo = "todos";      // "todos" | "M" | "F"
String filtroCor  = "todas";      // "todas" | uma cor
String filtroPelagem = "todas";   // "todas" | curta | média | longa
boolean filtroComDono = false;    // tecla 4
boolean filtroAdocao  = false;    // tecla 5

String filtroRaca = "todas";       // tecla B (ciclo)
ArrayList<String> racasDisponiveis = new ArrayList<String>();
int racaIdx = 0;

String[] coresCiclo = {"todas", "preto", "branco", "caramelo", "cinza", "malhada"};
int corIdx = 0;

String[] pelagemCiclo = {"todas", "curta", "média", "longa"};
int pelagemIdx = 0;

// =====================================================
// QUADROS (AJUSTADOS PARA CABER MAIS)
// =====================================================
float quadroW = 150;   // antes 210
float quadroH = 100;   // antes 140
float margemX = 50;    // antes 80
float margemY = 60;    // antes 90
float espacoX = 12;    // antes 18
float espacoY = 12;    // antes 18

// altura da legenda (detalhes embaixo do quadro)
float legendaH = 26;   // antes 34

// =====================================================
// UI
// =====================================================
PFont uiFont;

// =====================================================
// SELEÇÃO (painel info)
// =====================================================
AnimalItem itemFocado = null;

// =====================================================
// DEBUG
// =====================================================
boolean DEBUG = false;

void setup() {
  size(1280, 720, P3D);
  smooth(8);
  uiFont = createFont("Arial", 14);
  textFont(uiFont);
  textMode(SHAPE);

  // Texturas (dentro de data/)
  texChao   = loadImage("assets/texturas/chao_madeira.jpg");
  texParede = loadImage("assets/texturas/parede_tijolo.jpg");
  texTecto  = loadImage("assets/texturas/tecto_gesso.jpg");

  println("Chao:", texChao);
  println("Parede:", texParede);
  println("Tecto:", texTecto);

  // Carrega BD
  carregarAnimaisDoNeo4j();

  // Monta lista de raças
  construirRacasDisponiveis();

  // aplica filtros e layout inicial
  aplicarFiltrosELayout();

  // garante que começa dentro da sala
  aplicarColisaoSala();
  if (usarParedeMeio) aplicarColisaoParedeMeio(camZ);
}

void draw() {
  background(240);

  // atualiza camera + colisão
  atualizarCamera();

  // LUZ BASE (sem lights())
  noLights();
  ambientLight(120, 120, 120);
  directionalLight(180, 180, 180, -0.3, -1, -0.2);

  // desenha sala + parede do meio
  desenharSalaTexturada();
  desenharParedeMeioMenor();

  // desenha quadros + luzes (limitadas)
  desenharQuadrosComLuz();

  // calcula item em foco para painel
  atualizarItemFocado();

  // UI 2D por cima
  hint(DISABLE_DEPTH_TEST);
  camera();
  noLights();
  desenharUI();
  desenharPainelInfo();
  hint(ENABLE_DEPTH_TEST);
}

// =====================================================
// CAMERA + COLISÃO (SEM VOAR)
// =====================================================
void atualizarCamera() {
  // mouse look
  float dx = (mouseX - pmouseX);
  float dy = (mouseY - pmouseY);

  yaw   += dx * mouseSens;
  pitch += dy * mouseSens;

  float limit = radians(80);
  pitch = constrain(pitch, -limit, limit);

  // direção de movimento: SOMENTE NO XZ (flat)
  PVector forward = getForwardFlat();

  // ✅ CORREÇÃO: right com sinal correto (D direita / A esquerda)
  PVector right = new PVector(-forward.z, 0, forward.x);
  right.normalize();

  float speed = 4.5;
  if (shiftDown) speed = 8.0;

  float prevZ = camZ;

  if (wDown) { camX += forward.x * speed; camZ += forward.z * speed; }
  if (sDown) { camX -= forward.x * speed; camZ -= forward.z * speed; }
  if (dDown) { camX += right.x   * speed; camZ += right.z   * speed; }
  if (aDown) { camX -= right.x   * speed; camZ -= right.z   * speed; }

  // altura fixa
  camY = 180;

  aplicarColisaoSala();
  if (usarParedeMeio) aplicarColisaoParedeMeio(prevZ);

  if (DEBUG) println("cam:", camX, camY, camZ);

  // olhar (usa pitch para olhar para cima/baixo)
  PVector look = getForwardLook();
  PVector center = new PVector(camX + look.x, camY + look.y, camZ + look.z);
  camera(camX, camY, camZ, center.x, center.y, center.z, 0, 1, 0);
}

PVector getForwardFlat() {
  float fx = sin(yaw);
  float fz = -cos(yaw);
  PVector f = new PVector(fx, 0, fz);
  f.normalize();
  return f;
}

PVector getForwardLook() {
  float fx = cos(pitch) * sin(yaw);
  float fy = sin(pitch);
  float fz = -cos(pitch) * cos(yaw);
  PVector f = new PVector(fx, fy, fz);
  f.normalize();
  return f;
}

void aplicarColisaoSala() {
  float xMin = -salaW/2 + playerRadius + wallPadding;
  float xMax =  salaW/2 - playerRadius - wallPadding;

  float zMin = -salaD/2 + playerRadius + wallPadding;
  float zMax =  salaD/2 - playerRadius - wallPadding;

  camX = constrain(camX, xMin, xMax);
  camZ = constrain(camZ, zMin, zMax);
}

// colisão só na faixa da parede menor (para não bloquear a sala inteira)
void aplicarColisaoParedeMeio(float prevZ) {
  float limite = playerRadius + wallPadding + meioEspessura/2.0;

  float x1 = -meioW/2.0;
  float x2 =  meioW/2.0;

  float faixaX1 = x1 - playerRadius - wallPadding;
  float faixaX2 = x2 + playerRadius + wallPadding;

  if (camX < faixaX1 || camX > faixaX2) return;

  if (prevZ > (meioZ + limite) && camZ <= (meioZ + limite)) camZ = (meioZ + limite);
  if (prevZ < (meioZ - limite) && camZ >= (meioZ - limite)) camZ = (meioZ - limite);
}

// =====================================================
// SALA TEXTURADA + PAREDE DO MEIO MENOR
// =====================================================
void desenharSalaTexturada() {
  textureMode(NORMAL);
  textureWrap(REPEAT);

  float x1 = -salaW/2;
  float x2 =  salaW/2;
  float z1 = -salaD/2;
  float z2 =  salaD/2;
  float y1 = 0;
  float y2 = salaH;

  float repParedeX = salaW / 260.0;
  float repParedeY = salaH / 260.0;
  float repChaoX   = salaW / 240.0;
  float repChaoZ   = salaD / 240.0;

  noStroke();

  // CHÃO
  beginShape(QUADS);
  if (texChao != null) texture(texChao);
  vertex(x1, y1, z2, 0, 0);
  vertex(x2, y1, z2, repChaoX, 0);
  vertex(x2, y1, z1, repChaoX, repChaoZ);
  vertex(x1, y1, z1, 0, repChaoZ);
  endShape();

  // TECTO
  beginShape(QUADS);
  if (texTecto != null) texture(texTecto);
  vertex(x1, y2, z1, 0, 0);
  vertex(x2, y2, z1, repChaoX, 0);
  vertex(x2, y2, z2, repChaoX, repChaoZ);
  vertex(x1, y2, z2, 0, repChaoZ);
  endShape();

  // FUNDO z1
  beginShape(QUADS);
  if (texParede != null) texture(texParede);
  vertex(x1, y1, z1, 0, repParedeY);
  vertex(x2, y1, z1, repParedeX, repParedeY);
  vertex(x2, y2, z1, repParedeX, 0);
  vertex(x1, y2, z1, 0, 0);
  endShape();

  // FRENTE z2
  beginShape(QUADS);
  if (texParede != null) texture(texParede);
  vertex(x2, y1, z2, 0, repParedeY);
  vertex(x1, y1, z2, repParedeX, repParedeY);
  vertex(x1, y2, z2, repParedeX, 0);
  vertex(x2, y2, z2, 0, 0);
  endShape();

  // ESQ x1
  beginShape(QUADS);
  if (texParede != null) texture(texParede);
  vertex(x1, y1, z2, 0, repParedeY);
  vertex(x1, y1, z1, repParedeX, repParedeY);
  vertex(x1, y2, z1, repParedeX, 0);
  vertex(x1, y2, z2, 0, 0);
  endShape();

  // DIR x2
  beginShape(QUADS);
  if (texParede != null) texture(texParede);
  vertex(x2, y1, z1, 0, repParedeY);
  vertex(x2, y1, z2, repParedeX, repParedeY);
  vertex(x2, y2, z2, repParedeX, 0);
  vertex(x2, y2, z1, 0, 0);
  endShape();
}

void desenharParedeMeioMenor() {
  if (!usarParedeMeio) return;

  float x1 = -meioW/2;
  float x2 =  meioW/2;
  float y1 = meioYBase;
  float y2 = meioYBase + meioH;

  float zA = meioZ - meioEspessura/2.0;
  float zB = meioZ + meioEspessura/2.0;

  float repX = meioW / 260.0;
  float repY = meioH / 260.0;

  noStroke();

  // face +Z
  beginShape(QUADS);
  if (texParede != null) texture(texParede);
  vertex(x1, y1, zB, 0, repY);
  vertex(x2, y1, zB, repX, repY);
  vertex(x2, y2, zB, repX, 0);
  vertex(x1, y2, zB, 0, 0);
  endShape();

  // face -Z
  beginShape(QUADS);
  if (texParede != null) texture(texParede);
  vertex(x2, y1, zA, 0, repY);
  vertex(x1, y1, zA, repX, repY);
  vertex(x1, y2, zA, repX, 0);
  vertex(x2, y2, zA, 0, 0);
  endShape();
}

// =====================================================
// QUADROS + LUZES LIMITADAS
// =====================================================
void desenharQuadrosComLuz() {
  int maxLights = 6;

  ArrayList<AnimalDist> proximos = new ArrayList<AnimalDist>();
  for (AnimalItem it : visiveis) {
    float dx = it.worldCX() - camX;
    float dy = it.worldCY() - camY;
    float dz = it.worldCZ() - camZ;
    float d2 = dx*dx + dy*dy + dz*dz;
    proximos.add(new AnimalDist(it, d2));
  }
  Collections.sort(proximos);

  for (int i = 0; i < min(maxLights, proximos.size()); i++) {
    AnimalItem it = proximos.get(i).it;
    pointLight(230, 230, 230, it.worldCX(), it.worldCY(), it.worldCZ());
  }

  for (AnimalItem it : visiveis) it.draw();
}

class AnimalDist implements Comparable<AnimalDist> {
  AnimalItem it;
  float d2;
  AnimalDist(AnimalItem it, float d2) { this.it = it; this.d2 = d2; }
  public int compareTo(AnimalDist other) {
    return (d2 < other.d2) ? -1 : (d2 > other.d2) ? 1 : 0;
  }
}

// =====================================================
// LAYOUT: 4 paredes + parede do meio com quadros e detalhes
// =====================================================
void aplicarFiltrosELayout() {
  visiveis.clear();

  for (AnimalItem it : todos) {
    if (!filtroTipo.equals("todos") && !it.tipo.equals(filtroTipo)) continue;
    if (!filtroSexo.equals("todos") && !it.sexo.equals(filtroSexo)) continue;
    if (!filtroCor.equals("todas") && !it.cor.equals(filtroCor)) continue;
    if (!filtroPelagem.equals("todas") && !it.pelagem.equals(filtroPelagem)) continue;
    if (!filtroRaca.equals("todas") && !it.raca.equals(filtroRaca)) continue;
    if (filtroComDono && !it.temDono) continue;
    if (filtroAdocao && !it.paraAdocao) continue;

    visiveis.add(it);
  }

  layoutQuadrosComParedeMeio();
  println("Filtros aplicados. Visiveis:", visiveis.size());
}

void layoutQuadrosComParedeMeio() {
  ArrayList<AnimalItem> meioFrente = new ArrayList<AnimalItem>();
  ArrayList<AnimalItem> meioTras   = new ArrayList<AnimalItem>();
  ArrayList<AnimalItem> resto      = new ArrayList<AnimalItem>();

  for (int i = 0; i < visiveis.size(); i++) {
    AnimalItem it = visiveis.get(i);
    if (usarParedeMeio && meioFrente.size() < meioMaxFrente) {
      meioFrente.add(it);
    } else if (usarParedeMeio && meioTras.size() < meioMaxTras) {
      meioTras.add(it);
    } else {
      resto.add(it);
    }
  }

  if (usarParedeMeio) {
    layoutMeioWallGrid(meioFrente, "MID_FRONT");
    layoutMeioWallGrid(meioTras,   "MID_BACK");
  }

  ArrayList<AnimalItem> b = new ArrayList<AnimalItem>();
  ArrayList<AnimalItem> f = new ArrayList<AnimalItem>();
  ArrayList<AnimalItem> l = new ArrayList<AnimalItem>();
  ArrayList<AnimalItem> r = new ArrayList<AnimalItem>();

  for (int i = 0; i < resto.size(); i++) {
    int wall = i % 4;
    AnimalItem it = resto.get(i);
    if (wall == 0) b.add(it);
    else if (wall == 1) f.add(it);
    else if (wall == 2) l.add(it);
    else r.add(it);
  }

  layoutWallGrid(b, "BACK");
  layoutWallGrid(f, "FRONT");
  layoutWallGrid(l, "LEFT");
  layoutWallGrid(r, "RIGHT");
}

void layoutMeioWallGrid(ArrayList<AnimalItem> items, String wall) {
  if (items.size() == 0) return;

  float larguraUtil = meioW - 2*40;
  float alturaUtil  = meioH - 2*30;

  float blocoH = quadroH + legendaH;

  int cols = max(1, floor((larguraUtil + espacoX) / (quadroW + espacoX)));
  int rowsMax = max(1, floor((alturaUtil + espacoY) / (blocoH + espacoY)));

  int n = items.size();
  int rowsNeed = ceil(n / float(cols));
  if (rowsNeed > rowsMax) {
    cols = ceil(n / float(rowsMax));
    cols = max(1, cols);
  }

  float totalW = cols*quadroW + (cols-1)*espacoX;
  float startU = -totalW/2;

  for (int i = 0; i < items.size(); i++) {
    int c = i % cols;
    int r = i / cols;

    float u = startU + c*(quadroW + espacoX);
    float y = meioYBase + 30 + r*(blocoH + espacoY);

    AnimalItem it = items.get(i);
    it.wall = wall;
    it.u = u;
    it.y = y;
  }
}

void layoutWallGrid(ArrayList<AnimalItem> items, String wall) {
  if (items.size() == 0) return;

  float larguraUtil;
  if (wall.equals("BACK") || wall.equals("FRONT")) larguraUtil = salaW - 2*margemX;
  else larguraUtil = salaD - 2*margemX;

  int cols = max(1, floor((larguraUtil + espacoX) / (quadroW + espacoX)));
  float alturaUtil = salaH - 2*margemY;
  int rowsMax = max(1, floor((alturaUtil + espacoY) / (quadroH + espacoY)));

  int n = items.size();
  int rowsNeed = ceil(n / float(cols));
  if (rowsNeed > rowsMax) {
    cols = ceil(n / float(rowsMax));
    cols = max(1, cols);
  }

  float totalW = cols*quadroW + (cols-1)*espacoX;
  float startU = -totalW/2;

  for (int i = 0; i < items.size(); i++) {
    int c = i % cols;
    int r = i / cols;

    float u = startU + c*(quadroW + espacoX);
    float y = margemY + r*(quadroH + espacoY);

    AnimalItem it = items.get(i);
    it.wall = wall;
    it.u = u;
    it.y = y;
  }
}

// =====================================================
// ITEM EM FOCO (painel)
// =====================================================
void atualizarItemFocado() {
  itemFocado = null;
  if (visiveis.size() == 0) return;

  PVector fwd = getForwardLook();
  float bestScore = 0;

  for (AnimalItem it : visiveis) {
    PVector vecTo = new PVector(it.worldCX() - camX, it.worldCY() - camY, it.worldCZ() - camZ);
    float dist = vecTo.mag();
    if (dist > 700) continue;

    vecTo.normalize();
    float dot = vecTo.dot(fwd);
    if (dot > 0.96) {
      float score = dot * (1.0 / max(1, dist));
      if (score > bestScore) { bestScore = score; itemFocado = it; }
    }
  }
}

// =====================================================
// UI
// =====================================================
void desenharUI() {
  fill(0, 140);
  noStroke();
  rect(12, 12, 980, 132, 8);

  fill(255);
  textAlign(LEFT, TOP);

  text("WASD mover (no chão) | Mouse olhar | SHIFT correr | R reset", 22, 20);
  text("Filtros: 1=cão  2=gato  3=vaca  0=todos  | 4=com dono  5=adoção", 22, 40);
  text("Sexo: M/F | C=cor | P=pelagem | B=raça | L=limpar filtros", 22, 60);

  String estado = "tipo:" + filtroTipo +
    "  raca:" + filtroRaca +
    "  dono:" + filtroComDono +
    "  adocao:" + filtroAdocao +
    "  sexo:" + filtroSexo +
    "  cor:" + filtroCor +
    "  pelagem:" + filtroPelagem;

  text(estado, 22, 86);

  String diag = "DIAG  todos:" + todos.size() + "  visiveis:" + visiveis.size() +
                "  texChao:" + (texChao!=null) + "  texParede:" + (texParede!=null) + "  texTecto:" + (texTecto!=null);
  text(diag, 22, 106);

  text(neo4jStatus, 22, 126);
}

void desenharPainelInfo() {
  if (itemFocado == null) return;

  float px = width - 360;
  float py = 16;
  float pw = 340;
  float ph = 210;

  fill(0, 160);
  noStroke();
  rect(px, py, pw, ph, 10);

  fill(255);
  textAlign(LEFT, TOP);

  AnimalItem it = itemFocado;

  text("Animal em foco", px + 14, py + 12);
  text("ID: " + it.id, px + 14, py + 36);
  text("Nome: " + it.nome, px + 14, py + 56);
  text("Tipo: " + it.tipo, px + 14, py + 76);
  text("Raça: " + it.raca, px + 14, py + 96);
  text("Sexo: " + it.sexo + " | Idade: " + it.idade, px + 14, py + 116);
  text("Cor: " + it.cor + " | Pelagem: " + it.pelagem, px + 14, py + 136);
  text("Para adoção: " + it.paraAdocao, px + 14, py + 156);
  text("Dono: " + (it.temDono ? it.donoNome : "(sem dono)"), px + 14, py + 176);
}

// =====================================================
// TECLAS
// =====================================================
void keyPressed() {
  if (key == 'w' || key == 'W') wDown = true;
  if (key == 'a' || key == 'A') aDown = true;
  if (key == 's' || key == 'S') sDown = true;
  if (key == 'd' || key == 'D') dDown = true;
  if (keyCode == SHIFT) shiftDown = true;

  if (key == 'r' || key == 'R') {
    camX = 0;
    camY = 180;
    camZ = 520;
    yaw = 0;
    pitch = 0;
    aplicarColisaoSala();
    if (usarParedeMeio) aplicarColisaoParedeMeio(camZ);
  }

  if (key == '1') { filtroTipo = "cão";   aplicarFiltrosELayout(); }
  if (key == '2') { filtroTipo = "gato";  aplicarFiltrosELayout(); }
  if (key == '3') { filtroTipo = "vaca";  aplicarFiltrosELayout(); }
  if (key == '0') { filtroTipo = "todos"; aplicarFiltrosELayout(); }

  if (key == '4') { filtroComDono = !filtroComDono; aplicarFiltrosELayout(); }
  if (key == '5') { filtroAdocao  = !filtroAdocao;  aplicarFiltrosELayout(); }

  if (key == 'm' || key == 'M') {
    filtroSexo = (filtroSexo.equals("M")) ? "todos" : "M";
    aplicarFiltrosELayout();
  }
  if (key == 'f' || key == 'F') {
    filtroSexo = (filtroSexo.equals("F")) ? "todos" : "F";
    aplicarFiltrosELayout();
  }

  if (key == 'c' || key == 'C') {
    corIdx = (corIdx + 1) % coresCiclo.length;
    filtroCor = coresCiclo[corIdx];
    aplicarFiltrosELayout();
  }

  if (key == 'p' || key == 'P') {
    pelagemIdx = (pelagemIdx + 1) % pelagemCiclo.length;
    filtroPelagem = pelagemCiclo[pelagemIdx];
    aplicarFiltrosELayout();
  }

  if (key == 'b' || key == 'B') {
    if (racasDisponiveis.size() == 0) return;
    racaIdx = (racaIdx + 1) % racasDisponiveis.size();
    filtroRaca = racasDisponiveis.get(racaIdx);
    aplicarFiltrosELayout();
  }

  if (key == 'l' || key == 'L') {
    filtroTipo = "todos";
    filtroSexo = "todos";
    filtroCor = "todas";
    filtroPelagem = "todas";
    filtroRaca = "todas";
    filtroComDono = false;
    filtroAdocao = false;
    corIdx = 0;
    pelagemIdx = 0;
    racaIdx = 0;
    aplicarFiltrosELayout();
  }
}

void keyReleased() {
  if (key == 'w' || key == 'W') wDown = false;
  if (key == 'a' || key == 'A') aDown = false;
  if (key == 's' || key == 'S') sDown = false;
  if (key == 'd' || key == 'D') dDown = false;
  if (keyCode == SHIFT) shiftDown = false;
}

// =====================================================
// NEO4J LOAD (HTTP)
// =====================================================
void carregarAnimaisDoNeo4j() {
  try {
    String cypher =
      "MATCH (a:Animal) " +
      "OPTIONAL MATCH (a)-[:TEM_DONO]->(p:Pessoa) " +
      "RETURN a.id AS id, a.nome AS nome, a.tipo AS tipo, a.raca AS raca, a.cor AS cor, " +
      "a.pelagem AS pelagem, a.sexo AS sexo, a.idade AS idade, a.paraAdocao AS paraAdocao, " +
      "a.img AS img, a.audio AS audio, p.nome AS dono " +
      "ORDER BY a.tipo, a.nome";

    String resp = neo4jCommit(cypher);
    JSONObject root = parseJSONObject(resp);

    if (root.hasKey("errors")) {
      JSONArray errs = root.getJSONArray("errors");
      if (errs != null && errs.size() > 0) {
        neo4jStatus = "Neo4j ERRO: " + errs.getJSONObject(0).getString("message");
        println(neo4jStatus);
        return;
      }
    }

    JSONArray results = root.getJSONArray("results");
    JSONObject r0 = results.getJSONObject(0);
    JSONArray data = r0.getJSONArray("data");

    todos.clear();

    for (int i = 0; i < data.size(); i++) {
      JSONObject rowObj = data.getJSONObject(i);
      JSONArray row = rowObj.getJSONArray("row");

      AnimalItem it = new AnimalItem();

      it.id         = asString(row.get(0));
      it.nome       = asString(row.get(1));
      it.tipo       = asString(row.get(2));
      it.raca       = asString(row.get(3));
      it.cor        = asString(row.get(4));
      it.pelagem    = asString(row.get(5));
      it.sexo       = asString(row.get(6));
      it.idade      = asInt(row.get(7));
      it.paraAdocao = asBool(row.get(8));
      it.imgPath    = asString(row.get(9));
      it.audioPath  = asString(row.get(10));
      it.donoNome   = asStringOrEmpty(row.get(11));
      it.temDono    = (it.donoNome.length() > 0);

      it.img = loadImage(it.imgPath);
      if (it.img == null) println("IMG NULL:", it.imgPath);

      todos.add(it);
    }

    neo4jStatus = "Neo4j OK: " + todos.size() + " animais";
    println(neo4jStatus);
  }
  catch (Exception e) {
    neo4jStatus = "Neo4j EXC: " + e.getMessage();
    println(neo4jStatus);
    e.printStackTrace();
  }
}

String neo4jCommit(String cypher) throws Exception {
  URL url = new URL(NEO4J_URL);
  HttpURLConnection con = (HttpURLConnection) url.openConnection();
  con.setRequestMethod("POST");
  con.setRequestProperty("Content-Type", "application/json; charset=UTF-8");

  String auth = NEO4J_USER + ":" + NEO4J_PASS;
  String basic = Base64.getEncoder().encodeToString(auth.getBytes("UTF-8"));
  con.setRequestProperty("Authorization", "Basic " + basic);

  con.setDoOutput(true);

  String payload = "{\"statements\":[{\"statement\":\"" + escapeJson(cypher) + "\"}]}";

  OutputStream os = con.getOutputStream();
  os.write(payload.getBytes("UTF-8"));
  os.close();

  InputStream is;
  if (con.getResponseCode() >= 200 && con.getResponseCode() < 300) is = con.getInputStream();
  else is = con.getErrorStream();

  BufferedReader br = new BufferedReader(new InputStreamReader(is, "UTF-8"));
  StringBuilder sb = new StringBuilder();
  String line;
  while ((line = br.readLine()) != null) sb.append(line);
  br.close();

  return sb.toString();
}

String escapeJson(String s) {
  return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "");
}

// helpers
String asString(Object o) {
  if (o == null) return "";
  return String.valueOf(o);
}
String asStringOrEmpty(Object o) {
  if (o == null) return "";
  String v = String.valueOf(o);
  if (v.equals("null")) return "";
  return v;
}
int asInt(Object o) {
  if (o == null) return 0;
  try { return int(float(String.valueOf(o))); }
  catch(Exception e) { return 0; }
}
boolean asBool(Object o) {
  if (o == null) return false;
  String v = String.valueOf(o).toLowerCase();
  return v.equals("true") || v.equals("1");
}

// =====================================================
// RAÇAS DISPONÍVEIS
// =====================================================
void construirRacasDisponiveis() {
  HashSet<String> set = new HashSet<String>();
  for (AnimalItem it : todos) {
    if (it.raca != null && it.raca.length() > 0) set.add(it.raca);
  }
  racasDisponiveis.clear();
  racasDisponiveis.add("todas");
  ArrayList<String> sorted = new ArrayList<String>(set);
  Collections.sort(sorted);
  racasDisponiveis.addAll(sorted);

  racaIdx = 0;
  filtroRaca = racasDisponiveis.get(0);

  println("Racas disponiveis:", racasDisponiveis);
}

// =====================================================
// CLASSE ITEM (com legenda embaixo) - TEXTO CORRETO
// =====================================================
class AnimalItem {
  String id = "";
  String nome = "";
  String tipo = "";
  String raca = "";
  String cor = "";
  String pelagem = "";
  String sexo = "";
  int idade = 0;
  boolean paraAdocao = false;
  boolean temDono = false;
  String donoNome = "";

  String imgPath = "";
  String audioPath = "";

  PImage img;

  // BACK, FRONT, LEFT, RIGHT, MID_FRONT, MID_BACK
  String wall = "BACK";
  float u = 0;
  float y = 120;

  float frameOffset = 8;

  float worldCX() { return worldCenter().x; }
  float worldCY() { return worldCenter().y; }
  float worldCZ() { return worldCenter().z; }

  PVector worldCenter() {
    float x1 = -salaW/2;
    float x2 =  salaW/2;
    float z1 = -salaD/2;
    float z2 =  salaD/2;

    float cx = 0, cy = y + quadroH/2, cz = 0;

    if (wall.equals("BACK")) {
      cx = u + quadroW/2;
      cz = z1 + frameOffset;
    } else if (wall.equals("FRONT")) {
      cx = -(u + quadroW/2);
      cz = z2 - frameOffset;
    } else if (wall.equals("LEFT")) {
      cx = x1 + frameOffset;
      cz = -(u + quadroW/2);
    } else if (wall.equals("RIGHT")) {
      cx = x2 - frameOffset;
      cz = (u + quadroW/2);
    } else if (wall.equals("MID_FRONT")) {
      cx = u + quadroW/2;
      cz = meioZ + meioEspessura/2.0 + frameOffset;
    } else if (wall.equals("MID_BACK")) {
      cx = u + quadroW/2;
      cz = meioZ - meioEspessura/2.0 - frameOffset;
    }

    return new PVector(cx, cy, cz);
  }

  void draw() {
    pushMatrix();

    float x1 = -salaW/2;
    float x2 =  salaW/2;
    float z1 = -salaD/2;
    float z2 =  salaD/2;

    if (wall.equals("BACK")) {
      translate(u, y, z1 + frameOffset);
    } else if (wall.equals("FRONT")) {
      translate(-u - quadroW, y, z2 - frameOffset);
      rotateY(PI);
    } else if (wall.equals("LEFT")) {
      translate(x1 + frameOffset, y, -u - quadroW);
      rotateY(HALF_PI);
    } else if (wall.equals("RIGHT")) {
      translate(x2 - frameOffset, y, u);
      rotateY(-HALF_PI);
    } else if (wall.equals("MID_FRONT")) {
      translate(u, y, meioZ + meioEspessura/2.0 + frameOffset);
    } else if (wall.equals("MID_BACK")) {
      translate(u + quadroW, y, meioZ - meioEspessura/2.0 - frameOffset);
      rotateY(PI);
    }

    // moldura
    noStroke();
    fill(20);
    beginShape(QUADS);
    vertex(-6, -6, 0);
    vertex(quadroW+6, -6, 0);
    vertex(quadroW+6, quadroH+6, 0);
    vertex(-6, quadroH+6, 0);
    endShape();

    // imagem
    if (img != null) {
      beginShape(QUADS);
      textureMode(NORMAL);
      texture(img);
      vertex(0, 0, 1, 0, 0);
      vertex(quadroW, 0, 1, 1, 0);
      vertex(quadroW, quadroH, 1, 1, 1);
      vertex(0, quadroH, 1, 0, 1);
      endShape();
    } else {
      fill(180, 0, 0);
      beginShape(QUADS);
      vertex(0, 0, 1);
      vertex(quadroW, 0, 1);
      vertex(quadroW, quadroH, 1);
      vertex(0, quadroH, 1);
      endShape();
    }

    // legenda (detalhes embaixo) - ✅ SEM FLIP, texto no sentido correto
    float ly = quadroH + 10;
    fill(0, 180);
    beginShape(QUADS);
    vertex(0, ly, 1);
    vertex(quadroW, ly, 1);
    vertex(quadroW, ly + legendaH, 1);
    vertex(0, ly + legendaH, 1);
    endShape();

    pushMatrix();
    translate(quadroW/2, ly + 11, 2);
    fill(255);
    textAlign(CENTER, CENTER);

    textSize(10);
    text(nome, 0, 0);

    textSize(9);
    String linha2 = tipo + " | " + raca + " | " + idade + "a";
    text(linha2, 0, 12);

    popMatrix();

    popMatrix();
  }
}
