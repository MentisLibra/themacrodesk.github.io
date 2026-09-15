//+------------------------------------------------------------------+
//|                                        CHOCH_XAU_EA_v118_ICM.mq5 |
//|                                                                  |
//|  Code C — Double CHOCH H4 + filtre 2 MM + Discount/Premium       |
//|  v1.18 — VERSION IC MARKETS : STOPS A L'ECHELLE DE L'ATR         |
//|                                                                  |
//|  POURQUOI CETTE VERSION EXISTE                                   |
//|                                                                  |
//|  Le run v1.17 sur ICMarketsSC-Demo a mesure 195 trades / PF 1,20 |
//|  / DD 14,57 % contre la reference 248 / 1,517 / 6,66 %. Cause :  |
//|  XAUUSD a 2 decimales chez IC Markets (_Point = 0.01) contre 3   |
//|  chez Swissquote. InpMinSLPoints = 5000 valait donc 50 $ au lieu |
//|  de 5 $. Ce plancher depassait systematiquement le plafond        |
//|  InpMaxSLPct = 1,2 %, et comme le code applique le plancher PUIS  |
//|  le plafond, le plafond ecrasait tout : 99 % des trades avaient  |
//|  un SL exactement a 1,2 % du prix. Le journal le montre ligne a  |
//|  ligne : "R 4953 pts (1.20%)", "R 4947 pts (1.20%)",             |
//|  "R 4860 pts (1.20%)", "R 5208 pts (1.20%)"...                   |
//|  Toute la logique structurelle de stop etait court-circuitee.    |
//|                                                                  |
//|  CE QUI CHANGE                                                   |
//|                                                                  |
//|  1. PLUS AUCUN PARAMETRE DE STOP EN POINTS NI EN % DU PRIX.      |
//|     Tampon, plancher et plafond sont exprimes en multiples de    |
//|     l'ATR D1. Un multiple d'ATR est invariant d'echelle : il     |
//|     donne le meme stop physique chez Swissquote, IC Markets ou   |
//|     n'importe quel autre courtier, quel que soit _Point.         |
//|       InpSLBufferATR = 0.05   (tampon au-dela du niveau)         |
//|       InpSLFloorATR  = 0.08   (plancher)                         |
//|       InpSLCapATR    = 0.60   (plafond)                          |
//|     La bande 0.08-0.60 est exactement le garde-fou du dashboard  |
//|     XAU de la passation. A 1,2 % du prix, l'ancien stop valait   |
//|     ~80-100 % de l'ATR D1 : tres au-dessus de la bande, ce qui   |
//|     aurait du declencher un refus.                               |
//|                                                                  |
//|  2. REFUS AU LIEU DE SILENCE.                                    |
//|     - OnInit refuse de demarrer si plancher >= plafond.          |
//|     - TryEnter refuse d'entrer si l'ATR D1 n'est pas disponible. |
//|       Un stop qu'on ne peut pas mettre a l'echelle n'est pas un  |
//|       stop, c'est un pari.                                       |
//|                                                                  |
//|  3. COMPTEURS D'ECRETAGE dans l'entonnoir.                       |
//|     "SL ramene au plancher" et "SL ramene au plafond". Si l'un   |
//|     des deux approche 100 % des trades, le stop structurel ne    |
//|     sert plus a rien et il faut le savoir en une ligne.          |
//|                                                                  |
//|  4. DIAGNOSTIC D'ECHELLE imprime au premier trade : _Point,      |
//|     _Digits, ATR D1, et le stop en $ ET en % du prix ET en       |
//|     multiple d'ATR. C'est la ligne qui aurait fait gagner la     |
//|     session precedente.                                          |
//|                                                                  |
//|  5. SWAP ET COMMISSION EXPRIMES EN R en fin de test.             |
//|     Sur le run v1.17 : swap -3147 CHF = -15,6 R sur un brut de   |
//|     +38,25 R. Le swap mangeait 41 % du resultat. La commission   |
//|     valait -107 CHF = -0,5 R. Avec une tenue moyenne de 93 h en  |
//|     achat sur l'or, le swap est le premier poste de cout, pas la |
//|     commission. La passation dit l'inverse : c'est vrai sur      |
//|     EUR/USD en intraday, faux ici.                               |
//|                                                                  |
//|  6. InpTrailStepR : pas minimal du suiveur, en R.                |
//|     DEFAUT 0 = comportement identique a avant. Le journal v1.17  |
//|     contient des milliers de PositionModify, parfois de 0.01 $.  |
//|     Inoffensif en backtest, intenable en reel (chaque modify est |
//|     une requete serveur). Mettre 0.05 apres le run de controle.  |
//|                                                                  |
//|  CE QUI NE CHANGE PAS : detection CHOCH, filtre MM, note de      |
//|  tendance, Ichimoku, confirmation H1, zone, dimensionnement,     |
//|  suiveur, session locale. Aucune logique de signal n'est touchee.|
//|                                                                  |
//|  ENVIRONNEMENT A UTILISER                                        |
//|    XAUUSD — ICMarketsSC (Raw Trading Ltd) — graphique H1          |
//|    2020.01.01 -> 2026.08.12 — TICKS REELS, qualite ~100 %         |
//|    Le run v1.17 tournait a 6 % de ticks reels sur M15 depuis     |
//|    2020.12.01 : telecharger l'historique complet avant.          |
//|                                                                  |
//|  IL N'Y A PLUS DE REFERENCE A REPRODUIRE.                        |
//|  Les 248 trades / +70,05 R de Swissquote ne sont pas             |
//|  transposables : symbole different, swap different, ticks        |
//|  differents. Ce run FONDE une nouvelle reference IC Markets.     |
//|  Noter ses chiffres et s'y tenir pour tous les runs suivants.    |
//|                                                                  |
//|  RESERVE A CONSERVER : le holdout 2024-2026 est consomme pour ce |
//|  code. Les 5 runs d'origine ont ete arbitres en regardant la     |
//|  ventilation annuelle complete, et le RUN 4 justifie la          |
//|  suppression du cote vendeur par le comportement de 2026. Tout   |
//|  resultat obtenu ici est in-sample. Seul un forward test         |
//|  fournira une periode propre.                                    |
//+------------------------------------------------------------------+
#property copyright "Code C"
#property link      ""
#property version   "1.18"
#property description "Double CHOCH H4 + 2 MM + confirmation H1 — stops a l'echelle de l'ATR"

#include <Trade\Trade.mqh>

//==================================================================
//  ENUMS
//==================================================================
enum ENUM_SL_MODE
  {
   SLMODE_FIB       = 0,  // 75% de Fibonacci uniquement
   SLMODE_EXTREME   = 1,  // Extreme de l'impulsion uniquement
   SLMODE_FURTHEST  = 2   // Le plus eloigne des deux (defaut)
  };

enum ENUM_ENTRY_MODE
  {
   ENTRY_LIMIT_ONLY = 0,  // Limite seule
   ENTRY_MARKET_OK  = 1   // Marche si deja en zone (defaut)
  };

enum ENUM_ENTRY_TRIGGER
  {
   TRIG_LIMIT_FIB    = 0,  // Ordre limite au fib (v1.01)
   TRIG_MARKET_ZONE  = 1,  // Marche a la confirmation, si deja en zone
   TRIG_MARKET_ANY   = 2   // Marche a la confirmation, zone ignoree (defaut)
  };

enum ENUM_KUMO_MODE
  {
   KUMO_OFF     = 0,  // Filtre Ichimoku inactif
   KUMO_PRO_IN  = 1,  // Pro-tendance + interieur du nuage (defaut)
   KUMO_STRICT  = 2   // Strict : interieur du nuage refuse
  };

enum ENUM_IMPULSE_MODE
  {
   IMP_LAST_LEG     = 0,  // Derniere jambe (v1.01)
   IMP_FULL_SEQ     = 1   // Sequence complete (v1.00)
  };

enum ENUM_SESSION_MODE
  {
   SESS_OFF    = 0,  // 24h (defaut)
   SESS_HARD   = 1,  // Hors fenetre : setup REJETE et consomme
   SESS_DEFER  = 2   // Hors fenetre : report (diagnostic)
  };

enum ENUM_DST_RULE
  {
   DST_NONE = 0,  // Serveur a offset fixe
   DST_US   = 1,  // DST americain (cas usuel FX, dont IC Markets)
   DST_EU   = 2   // DST europeen
  };

//==================================================================
//  INPUTS
//==================================================================
input group "=== Structure H4 : CHOCH ==="
input int             InpSwingBars        = 2;      // Fractale H4 (barres de chaque cote)
input int             InpH4Lookback       = 400;    // Profondeur d'analyse H4 (barres)
input int             InpBreaksRequired   = 1;      // Cassures consecutives requises
input ENUM_IMPULSE_MODE InpImpulseMode    = IMP_LAST_LEG; // Ancrage de l'impulsion
input int             InpImpulseLookback  = 20;     // Recherche du pied (sequence complete)
input int             InpSetupExpiryBarsH4= 12;     // Peremption du setup (barres H4)
input double          InpMaxRangePct      = 0.0;    // Amplitude max de l'impulsion (% du prix, 0 = off)

input group "=== Filtre de tendance : 2 moyennes mobiles (H4) ==="
input int             InpMAFast           = 50;     // MM rapide (periode)
input int             InpMASlow           = 200;    // MM lente (periode)
input ENUM_MA_METHOD  InpMAMethod         = MODE_EMA; // Methode des MM
input int             InpATRPeriod        = 14;     // ATR H4 (ecartement des MM)
input double          InpSepATR           = 0.25;   // Ecartement MM mini en ATR
input double          InpMinTrendScore    = 0.0;    // Note mini pour trader (0 = aucun filtre)

input group "=== Bougie contre-tendance + confirmation H1 ==="
input bool            InpUseCounterCandle = true;   // Exiger une bougie H4 contre-tendance
input int             InpCounterMaxBarsH4 = 8;      // Delai max pour la trouver (barres H4)
input int             InpH1ConfirmBars    = 2;      // Bougies H1 de confirmation consecutives
input int             InpH1ConfirmMaxBars = 24;     // Delai max de confirmation (barres H1)

input group "=== Zone Discount / Premium & entree ==="
input ENUM_ENTRY_TRIGGER InpEntryTrigger  = TRIG_MARKET_ANY; // Declenchement de l'entree
input ENUM_ENTRY_MODE InpEntryMode        = ENTRY_MARKET_OK; // (mode limite seulement)
input double          InpEntryFib         = 0.50;   // Niveau d'entree (0.50 = equilibre)
input int             InpPendingExpiryBarsH1 = 12;  // Peremption de l'ordre en attente (barres H1)

input group "=== Stop loss — TOUT EN MULTIPLES D'ATR D1 (invariant d'echelle) ==="
input ENUM_SL_MODE    InpSLMode           = SLMODE_FURTHEST; // Placement du SL
input double          InpSLFib            = 0.75;   // Niveau Fibonacci du SL
input int             InpATRFilterPeriod  = 14;     // Periode de l'ATR journalier
input double          InpSLBufferATR      = 0.05;   // Tampon au-dela du niveau (x ATR D1)
input double          InpSLFloorATR       = 0.08;   // PLANCHER du SL (x ATR D1)
input double          InpSLCapATR         = 0.60;   // PLAFOND du SL (x ATR D1)

input group "=== Sens autorises ==="
input bool            InpTradeLong        = true;   // Autoriser les achats
input bool            InpTradeShort       = false;  // Autoriser les ventes

input group "=== Filtre Ichimoku H4 ==="
input ENUM_KUMO_MODE  InpKumoMode         = KUMO_PRO_IN; // Mode du filtre Ichimoku
input int             InpTenkan           = 9;      // Tenkan-sen
input int             InpKijun            = 26;     // Kijun-sen
input int             InpSenkou           = 52;     // Senkou Span B

input group "=== Risque & volumes ==="
input double          InpRiskTotalMin     = 0.50;   // Risque total mini (% du capital)
input double          InpRiskTotalMax     = 1.00;   // Risque total maxi (% du capital)
input bool            InpUseTrendRisk     = true;   // Moduler le risque par la note de tendance
input double          InpMaxMarginPct     = 30.0;   // Marge maxi engagee (% des fonds)
input int             InpMagic            = 20260813; // Magic number
input int             InpSlippage         = 30;     // Deviation autorisee (points)

input group "=== Sorties : TP / suiveur ==="
input double          InpTP1_R            = 0.0;    // TP de la jambe A (en R, 0 = jambe unique)
input double          InpTP2_R            = 0.0;    // TP de la jambe B (en R, 0 = aucun)
input double          InpTrailStartR      = 1.0;    // Declenchement du suiveur (en R)
input double          InpTrailDistR       = 1.0;    // Distance du suiveur (en R)
input double          InpTrailStepR       = 0.0;    // Pas mini du suiveur (en R, 0 = ancien comportement)
input bool            InpBEafterTP1       = false;  // Jambe B au seuil de rentabilite a TP1
input double          InpBEBufferR        = 0.05;   // Tampon du seuil (en R)

input group "=== Session (heure LOCALE europeenne, DST automatique) ==="
input ENUM_SESSION_MODE InpSessionMode    = SESS_OFF; // Mode de session
input int             InpLocalStartHour   = 8;      // Debut de fenetre (heure locale EU)
input int             InpLocalStartMin    = 0;      // Debut (minutes)
input int             InpLocalEndHour     = 17;     // Fin de fenetre (heure locale EU)
input int             InpLocalEndMin      = 30;     // Fin (minutes)
input int             InpServerGMTWinter  = 2;      // Offset GMT du serveur en hiver
input ENUM_DST_RULE   InpServerDST        = DST_US; // Regle DST suivie par le serveur
input bool            InpCancelPendingWE  = true;   // Annuler les attentes avant le week-end
input int             InpFridayCancelHour = 22;     // Heure d'annulation du vendredi (SERVEUR)

input group "=== Journal ==="
input bool            InpVerbose          = true;   // Journal detaille
input bool            InpWriteCSV         = true;   // Ecrire le CSV d'analyse
input string          InpCSVName          = "CHOCH_XAU_trades.csv"; // Nom du fichier CSV

//==================================================================
//  GLOBALS
//==================================================================
CTrade   trade;

int      hMAFast = INVALID_HANDLE;
int      hMASlow = INVALID_HANDLE;
int      hATR    = INVALID_HANDLE;
int      hATRD1  = INVALID_HANDLE;
int      hIchi   = INVALID_HANDLE;

datetime g_lastH4Bar = 0;
datetime g_lastH1Bar = 0;

bool     g_expirationOK  = true;
bool     g_scalePrinted  = false;

// --- compteurs d'entonnoir --------------------------------------
long s_armed=0, s_rejScore=0, s_rejRange=0, s_counterOK=0, s_counterKO=0;
long s_confirm=0, s_confirmKO=0, s_placed=0, s_market=0, s_limit=0;
long s_sendFail=0, s_marketClosed=0, s_filled=0;
long s_invalid=0, s_setupExpired=0, s_volZero=0, s_capped=0;
long s_outOfZone=0, s_rejKumo=0, s_rejDir=0, s_rejSession=0;
long s_noATR=0, s_clampFloor=0, s_clampCap=0, s_clampStops=0;

// --- etat du setup ----------------------------------------------
struct SetupState
  {
   bool     active;
   int      dir;
   datetime tBreak;
   double   impHigh;
   double   impLow;
   bool     counterOK;
   int      h1Count;
   datetime tLastH1;
   int      h1Elapsed;
   int      h4Elapsed;
   double   score;
   bool     ordersPlaced;
  };
SetupState g_setup;

datetime g_lastArmedBreak = 0;

// --- suivi des positions ----------------------------------------
#define MAX_TRACK 16
struct PosTrack
  {
   ulong    ticket;
   int      dir;
   double   entry;
   double   rDist;
   bool     legB;
   bool     beDone;
   double   score;
   double   riskPct;
   datetime tOpen;
   double   impHigh;
   double   impLow;
   int      excIdx;
  };
PosTrack g_track[MAX_TRACK];
int      g_trackN = 0;

// --- excursions et contexte -------------------------------------
#define MAX_EXC 8192
ulong    e_id[MAX_EXC];
double   e_mfe[MAX_EXC], e_mae[MAX_EXC];
double   e_atrD1[MAX_EXC], e_atrH4[MAX_EXC], e_range[MAX_EXC], e_kumo[MAX_EXC];
double   e_spread[MAX_EXC];
int      e_n = 0;

double   g_entryATRD1 = 0.0, g_entryATRH4 = 0.0, g_entryRange = 0.0, g_entryKumo = 0.0;
double   g_entrySpread = 0.0;

int ExcNew(const ulong id)
  {
   if(e_n >= MAX_EXC) return -1;
   e_id[e_n]     = id;
   e_mfe[e_n]    = 0.0;
   e_mae[e_n]    = 0.0;
   e_atrD1[e_n]  = g_entryATRD1;
   e_atrH4[e_n]  = g_entryATRH4;
   e_range[e_n]  = g_entryRange;
   e_kumo[e_n]   = g_entryKumo;
   e_spread[e_n] = g_entrySpread;
   e_n++;
   return e_n - 1;
  }

int ExcFind(const ulong id)
  {
   for(int i = e_n - 1; i >= 0; i--)
      if(e_id[i] == id) return i;
   return -1;
  }

int KumoState()
  {
   double a[1], b[1], c[1];
   if(CopyBuffer(hIchi, SENKOUSPANA_LINE, 1, 1, a) < 1) return 99;
   if(CopyBuffer(hIchi, SENKOUSPANB_LINE, 1, 1, b) < 1) return 99;
   if(CopyClose(_Symbol, PERIOD_H4, 1, 1, c) < 1)       return 99;
   double top = MathMax(a[0], b[0]);
   double bot = MathMin(a[0], b[0]);
   if(c[0] > top) return  1;
   if(c[0] < bot) return -1;
   return 0;
  }

double ATRValue(const int handle)
  {
   double a[1];
   if(CopyBuffer(handle, 0, 1, 1, a) < 1) return 0.0;
   return a[0];
  }

//==================================================================
//  UTILITAIRES
//==================================================================
void Log(const string msg) { if(InpVerbose) Print(msg); }
double Pt() { return _Point; }
double NP(const double price) { return NormalizeDouble(price, _Digits); }

//------------------------------------------------------------------
double NormalizeVolume(double vol)
  {
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vstep <= 0.0) vstep = 0.01;
   vol = MathFloor(vol / vstep + 1e-8) * vstep;
   if(vol < vmin) return 0.0;
   if(vol > vmax) vol = vmax;
   int digv = 2;
   if(vstep >= 0.1)       digv = 1;
   else if(vstep >= 0.01) digv = 2;
   else                   digv = 3;
   return NormalizeDouble(vol, digv);
  }

//------------------------------------------------------------------
double LossPerLot(const double slDistance)
  {
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0.0 || tv <= 0.0) return 0.0;
   return (slDistance / ts) * tv;
  }

//------------------------------------------------------------------
double CalcVolume(const double slDistance, const double riskPct, const int dir, const double price)
  {
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk = eq * riskPct / 100.0;
   double lpl  = LossPerLot(slDistance);
   if(lpl <= 0.0) return 0.0;

   double vol = NormalizeVolume(risk / lpl);
   if(vol <= 0.0) return 0.0;

   double margin = 0.0;
   ENUM_ORDER_TYPE ot = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcMargin(ot, _Symbol, vol, price, margin) && margin > 0.0)
     {
      double maxMargin = eq * InpMaxMarginPct / 100.0;
      if(margin > maxMargin)
        {
         double v2 = NormalizeVolume(vol * (maxMargin / margin));
         if(v2 > 0.0) { s_capped++; Log(StringFormat("VOLUME PLAFONNE (marge) : %.2f -> %.2f", vol, v2)); vol = v2; }
         else return 0.0;
        }
     }
   return vol;
  }

//==================================================================
//  CONVERSION HORAIRE SERVEUR -> LOCAL EUROPEEN
//==================================================================
datetime LastSundayUTC(const int y, const int m, const int hUTC)
  {
   MqlDateTime d;
   ZeroMemory(d);
   d.year = y; d.mon = m; d.day = 31; d.hour = hUTC; d.min = 0; d.sec = 0;
   datetime t = StructToTime(d);
   MqlDateTime x;
   TimeToStruct(t, x);
   t -= x.day_of_week * 86400;      // day_of_week : 0 = dimanche
   return t;
  }

datetime NthSundayUTC(const int y, const int m, const int n, const int hUTC)
  {
   MqlDateTime d;
   ZeroMemory(d);
   d.year = y; d.mon = m; d.day = 1; d.hour = hUTC; d.min = 0; d.sec = 0;
   datetime t = StructToTime(d);
   MqlDateTime x;
   TimeToStruct(t, x);
   int add = (7 - x.day_of_week) % 7;
   t += (add + (n - 1) * 7) * 86400;
   return t;
  }

bool IsEU_DST(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return (t >= LastSundayUTC(d.year, 3, 1) && t < LastSundayUTC(d.year, 10, 1));
  }

bool IsUS_DST(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return (t >= NthSundayUTC(d.year, 3, 2, 7) && t < NthSundayUTC(d.year, 11, 1, 6));
  }

int ServerOffsetGMT(const datetime tServer)
  {
   int off = InpServerGMTWinter;
   if(InpServerDST == DST_US && IsUS_DST(tServer)) off++;
   if(InpServerDST == DST_EU && IsEU_DST(tServer)) off++;
   return off;
  }

//  Les bornes de DST sont testees sur l'horodatage serveur au lieu de
//  l'UTC. L'erreur vaut au plus 2-3 heures, deux fois par an, un
//  dimanche entre 01h et 07h : marche ferme ou quasi.
datetime ServerToLocalEU(const datetime tServer)
  {
   int offServer = ServerOffsetGMT(tServer);
   int offLocal  = 1 + (IsEU_DST(tServer) ? 1 : 0);
   return tServer - (offServer - offLocal) * 3600;
  }

bool InSessionLocal(const datetime tServer)
  {
   if(InpSessionMode == SESS_OFF) return true;
   MqlDateTime d;
   TimeToStruct(ServerToLocalEU(tServer), d);
   int cur   = d.hour * 60 + d.min;
   int start = InpLocalStartHour * 60 + InpLocalStartMin;
   int end   = InpLocalEndHour   * 60 + InpLocalEndMin;
   if(start <= end) return (cur >= start && cur < end);
   return (cur >= start || cur < end);
  }

//  Blocs figes d'avance. NE PAS redecouper apres avoir vu les
//  resultats : 195 trades sur 24 tranches font ~8 trades par tranche,
//  sous le seuil de 30 du protocole, et c'est exactement ce qui a
//  produit le gradient horaire fantome sur EUR/USD.
string BlockName(const datetime tServer)
  {
   MqlDateTime d;
   TimeToStruct(ServerToLocalEU(tServer), d);
   int mn = d.hour * 60 + d.min;
   if(mn >= 480  && mn < 1050) return "JOUR";   // 08:00 - 17:30
   if(mn >= 1050 && mn < 1410) return "SOIR";   // 17:30 - 23:30
   return "NUIT";                                // 23:30 - 08:00
  }

//------------------------------------------------------------------
string BuildComment(const bool legB, const double rDist, const double score)
  {
   int pts = (int)MathRound(rDist / Pt());
   return StringFormat("C%s%dS%d", (legB ? "B" : "A"), pts, (int)MathRound(score));
  }

bool ParseComment(const string cmt, bool &legB, double &rDist, double &score)
  {
   score = 0.0;
   if(StringLen(cmt) < 3) return false;
   if(StringSubstr(cmt, 0, 1) != "C") return false;
   string L = StringSubstr(cmt, 1, 1);
   if(L != "A" && L != "B") return false;
   legB = (L == "B");
   int sp = StringFind(cmt, "S", 2);
   string rp = (sp > 2 ? StringSubstr(cmt, 2, sp - 2) : StringSubstr(cmt, 2));
   rDist = (double)StringToInteger(rp) * Pt();
   if(sp > 2) score = (double)StringToInteger(StringSubstr(cmt, sp + 1));
   return (rDist > 0.0);
  }

//==================================================================
//  STRUCTURE H4
//==================================================================
bool IsPivotHigh(const MqlRates &r[], const int i, const int n, const int size)
  {
   if(i - n < 0 || i + n >= size) return false;
   double h = r[i].high;
   for(int k = 1; k <= n; k++)
     {
      if(r[i-k].high >= h) return false;
      if(r[i+k].high >  h) return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &r[], const int i, const int n, const int size)
  {
   if(i - n < 0 || i + n >= size) return false;
   double l = r[i].low;
   for(int k = 1; k <= n; k++)
     {
      if(r[i-k].low <= l) return false;
      if(r[i+k].low <  l) return false;
     }
   return true;
  }

//------------------------------------------------------------------
bool ScanStructure(const MqlRates &r[], const int size,
                   int &dirOut, int &countOut, int &firstBarOut, int &lastBarOut)
  {
   dirOut = 0; countOut = 0; firstBarOut = -1; lastBarOut = -1;

   double lastPH = 0.0, lastPL = 0.0;
   bool   phOK = false, plOK = false;
   int    n = InpSwingBars;

   for(int i = 0; i < size; i++)
     {
      int p = i - n;
      if(p >= n)
        {
         if(IsPivotHigh(r, p, n, size)) { lastPH = r[p].high; phOK = true; }
         if(IsPivotLow (r, p, n, size)) { lastPL = r[p].low;  plOK = true; }
        }

      if(phOK && r[i].close > lastPH)
        {
         if(dirOut == 1) countOut++;
         else { dirOut = 1; countOut = 1; firstBarOut = i; }
         lastBarOut = i;
         phOK = false;
        }
      else if(plOK && r[i].close < lastPL)
        {
         if(dirOut == -1) countOut++;
         else { dirOut = -1; countOut = 1; firstBarOut = i; }
         lastBarOut = i;
         plOK = false;
        }
     }
   return (dirOut != 0 && lastBarOut >= 0);
  }

//------------------------------------------------------------------
bool BuildImpulseLastLeg(const MqlRates &r[], const int size, const int dir,
                         const int lastBar, double &impHigh, double &impLow)
  {
   int n = InpSwingBars;
   int anchor = -1;

   for(int p = lastBar - 1; p >= n; p--)
     {
      if(dir > 0 && IsPivotLow (r, p, n, size)) { anchor = p; break; }
      if(dir < 0 && IsPivotHigh(r, p, n, size)) { anchor = p; break; }
     }
   if(anchor < 0) return false;

   if(dir > 0)
     {
      double lo = r[anchor].low;
      double hi = r[anchor].high;
      for(int i = anchor; i < size; i++)
         if(r[i].high > hi) hi = r[i].high;
      impLow = lo; impHigh = hi;
     }
   else
     {
      double hi = r[anchor].high;
      double lo = r[anchor].low;
      for(int i = anchor; i < size; i++)
         if(r[i].low < lo) lo = r[i].low;
      impHigh = hi; impLow = lo;
     }
   return (impHigh - impLow > 0.0);
  }

//------------------------------------------------------------------
bool BuildImpulseFullSeq(const MqlRates &r[], const int size, const int dir,
                         const int firstBar, double &impHigh, double &impLow)
  {
   int from = MathMax(0, firstBar - InpImpulseLookback);
   impHigh = 0.0; impLow = 0.0;

   if(dir > 0)
     {
      int idxHigh = firstBar;
      double hi = r[firstBar].high;
      for(int i = firstBar; i < size; i++)
         if(r[i].high > hi) { hi = r[i].high; idxHigh = i; }
      double lo = r[from].low;
      for(int i = from; i <= idxHigh; i++)
         if(r[i].low < lo) lo = r[i].low;
      impHigh = hi; impLow = lo;
     }
   else
     {
      int idxLow = firstBar;
      double lo = r[firstBar].low;
      for(int i = firstBar; i < size; i++)
         if(r[i].low < lo) { lo = r[i].low; idxLow = i; }
      double hi = r[from].high;
      for(int i = from; i <= idxLow; i++)
         if(r[i].high > hi) hi = r[i].high;
      impHigh = hi; impLow = lo;
     }
   return (impHigh > impLow);
  }

//==================================================================
//  NOTE DE TENDANCE
//==================================================================
double TrendScore(const int dir)
  {
   double fast[3], slow[3], atr[1], cl[1];
   if(CopyBuffer(hMAFast, 0, 1, 3, fast) < 3) return 0.0;
   if(CopyBuffer(hMASlow, 0, 1, 3, slow) < 3) return 0.0;
   if(CopyBuffer(hATR,    0, 1, 1, atr ) < 1) return 0.0;
   if(CopyClose(_Symbol, PERIOD_H4, 1, 1, cl) < 1) return 0.0;

   double f0 = fast[2], f2 = fast[0], s0 = slow[2], a = atr[0], c = cl[0];
   double sc = 0.0;
   if(dir > 0)
     {
      if(f0 > s0)                            sc += 40.0;
      if(c  > f0)                            sc += 20.0;
      if(f0 > f2)                            sc += 20.0;
      if(a > 0 && (f0 - s0) > InpSepATR * a) sc += 20.0;
     }
   else
     {
      if(f0 < s0)                            sc += 40.0;
      if(c  < f0)                            sc += 20.0;
      if(f0 < f2)                            sc += 20.0;
      if(a > 0 && (s0 - f0) > InpSepATR * a) sc += 20.0;
     }
   return sc;
  }

double RiskFromScore(const double score)
  {
   if(!InpUseTrendRisk) return InpRiskTotalMax;
   double lo = MathMin(InpRiskTotalMin, InpRiskTotalMax);
   double hi = MathMax(InpRiskTotalMin, InpRiskTotalMax);
   return lo + (hi - lo) * (score / 100.0);
  }

//==================================================================
//  SETUP
//==================================================================
void ResetSetup()
  {
   g_setup.active       = false;
   g_setup.dir          = 0;
   g_setup.tBreak       = 0;
   g_setup.impHigh      = 0.0;
   g_setup.impLow       = 0.0;
   g_setup.counterOK    = false;
   g_setup.h1Count      = 0;
   g_setup.tLastH1      = 0;
   g_setup.h1Elapsed    = 0;
   g_setup.h4Elapsed    = 0;
   g_setup.score        = 0.0;
   g_setup.ordersPlaced = false;
  }

double FibLevel(const int dir, const double impHigh, const double impLow, const double f)
  {
   double range = impHigh - impLow;
   if(dir > 0) return impHigh - f * range;
   return impLow + f * range;
  }

//==================================================================
//  SUIVI DES POSITIONS
//==================================================================
void TrackAdd(const ulong ticket, const int dir, const double entry, const double rDist,
              const bool legB, const double score, const double riskPct,
              const double impHigh, const double impLow)
  {
   if(g_trackN >= MAX_TRACK) return;
   g_track[g_trackN].ticket  = ticket;
   g_track[g_trackN].dir     = dir;
   g_track[g_trackN].entry   = entry;
   g_track[g_trackN].rDist   = rDist;
   g_track[g_trackN].legB    = legB;
   g_track[g_trackN].beDone  = false;
   g_track[g_trackN].score   = score;
   g_track[g_trackN].riskPct = riskPct;
   g_track[g_trackN].tOpen   = TimeCurrent();
   g_track[g_trackN].impHigh = impHigh;
   g_track[g_trackN].impLow  = impLow;
   int ei = ExcFind(ticket);
   if(ei < 0) ei = ExcNew(ticket);
   g_track[g_trackN].excIdx  = ei;
   g_trackN++;
  }

int TrackFind(const ulong ticket)
  {
   for(int i = 0; i < g_trackN; i++)
      if(g_track[i].ticket == ticket) return i;
   return -1;
  }

void TrackPurge()
  {
   int w = 0;
   for(int i = 0; i < g_trackN; i++)
      if(PositionSelectByTicket(g_track[i].ticket))
        {
         if(w != i) g_track[w] = g_track[i];
         w++;
        }
   g_trackN = w;
  }

//==================================================================
//  OUVERTURE
//==================================================================
bool PlaceLegs(const int dir, const double entryPrice, const double sl,
               const bool market, const double score, const double riskPct,
               const double impHigh, const double impLow)
  {
   double rDist = MathAbs(entryPrice - sl);
   if(rDist <= 0.0) return false;

   double totalVol = CalcVolume(rDist, riskPct, dir, entryPrice);
   if(totalVol <= 0.0) { s_volZero++; Log("Volume nul : trade abandonne."); return false; }

   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double volA = 0.0, volB = 0.0;
   if(InpTP1_R > 0.0)
     {
      volA = NormalizeVolume(totalVol / 2.0);
      volB = NormalizeVolume(totalVol - volA);
      if(volA < vmin || volB < vmin)
        {
         volA = 0.0;
         volB = NormalizeVolume(totalVol);
         Log("Volume insuffisant pour deux jambes : jambe B seule.");
        }
     }
   else
      volB = NormalizeVolume(totalVol);

   if(volB < vmin && volA < vmin) { s_volZero++; return false; }

   double tp1 = (dir > 0 ? entryPrice + InpTP1_R * rDist : entryPrice - InpTP1_R * rDist);
   double tp2 = 0.0;
   if(InpTP2_R > 0.0)
      tp2 = (dir > 0 ? entryPrice + InpTP2_R * rDist : entryPrice - InpTP2_R * rDist);

   datetime exp = 0;
   ENUM_ORDER_TYPE_TIME tt = ORDER_TIME_GTC;
   if(!market)
     {
      exp = TimeCurrent() + (datetime)(InpPendingExpiryBarsH1 * PeriodSeconds(PERIOD_H1));
      if(g_expirationOK) tt = ORDER_TIME_SPECIFIED;
     }

   bool anyOK = false;
   bool closed = false;

   // --- jambe A --------------------------------------------------
   if(volA >= vmin)
     {
      string cA = BuildComment(false, rDist, score);
      bool ok;
      if(market)
         ok = (dir > 0) ? trade.Buy (volA, _Symbol, 0.0, NP(sl), NP(tp1), cA)
                        : trade.Sell(volA, _Symbol, 0.0, NP(sl), NP(tp1), cA);
      else
         ok = (dir > 0) ? trade.BuyLimit (volA, NP(entryPrice), _Symbol, NP(sl), NP(tp1), tt, exp, cA)
                        : trade.SellLimit(volA, NP(entryPrice), _Symbol, NP(sl), NP(tp1), tt, exp, cA);
      if(!ok)
        {
         s_sendFail++;
         uint rc = trade.ResultRetcode();
         if(rc == TRADE_RETCODE_MARKET_CLOSED) { closed = true; s_marketClosed++; }
         Print("ECHEC jambe A : ", trade.ResultRetcodeDescription());
        }
      else
        {
         anyOK = true;
         if(market)
           {
            ulong tk = trade.ResultDeal(), pos = 0;
            if(HistoryDealSelect(tk)) pos = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
            if(pos > 0) TrackAdd(pos, dir, trade.ResultPrice(), rDist, false, score, riskPct, impHigh, impLow);
           }
        }
     }

   // --- jambe B --------------------------------------------------
   if(volB >= vmin)
     {
      string cB = BuildComment(true, rDist, score);
      bool ok;
      if(market)
         ok = (dir > 0) ? trade.Buy (volB, _Symbol, 0.0, NP(sl), (tp2 > 0 ? NP(tp2) : 0.0), cB)
                        : trade.Sell(volB, _Symbol, 0.0, NP(sl), (tp2 > 0 ? NP(tp2) : 0.0), cB);
      else
         ok = (dir > 0) ? trade.BuyLimit (volB, NP(entryPrice), _Symbol, NP(sl), (tp2 > 0 ? NP(tp2) : 0.0), tt, exp, cB)
                        : trade.SellLimit(volB, NP(entryPrice), _Symbol, NP(sl), (tp2 > 0 ? NP(tp2) : 0.0), tt, exp, cB);
      if(!ok)
        {
         s_sendFail++;
         uint rc = trade.ResultRetcode();
         if(rc == TRADE_RETCODE_MARKET_CLOSED) { closed = true; s_marketClosed++; }
         Print("ECHEC jambe B : ", trade.ResultRetcodeDescription());
        }
      else
        {
         anyOK = true;
         if(market)
           {
            ulong tk = trade.ResultDeal(), pos = 0;
            if(HistoryDealSelect(tk)) pos = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
            if(pos > 0) TrackAdd(pos, dir, trade.ResultPrice(), rDist, true, score, riskPct, impHigh, impLow);
           }
        }
     }

   if(anyOK)
     {
      s_placed++;
      if(market) s_market++; else s_limit++;
      double atr = g_entryATRD1;
      Log(StringFormat("ENTREE %s %s | %s local | prix %.*f | SL %.*f | R %.2f $ = %.2f%% du prix = %.2f x ATR D1 | note %.0f | risque %.2f%% | vol %.2f+%.2f",
                       (dir > 0 ? "LONG" : "SHORT"), (market ? "marche" : "limite"),
                       BlockName(TimeCurrent()), _Digits, entryPrice, _Digits, sl,
                       rDist, 100.0 * rDist / entryPrice, (atr > 0 ? rDist / atr : 0.0),
                       score, riskPct, volA, volB));
     }
   else if(closed)
      Log("Marche ferme : setup conserve, nouvelle tentative a la prochaine confirmation.");

   return anyOK;
  }

//==================================================================
//  DECLENCHEMENT
//==================================================================
void TryEnter()
  {
   if(g_setup.ordersPlaced) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagic) return;
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk > 0 && OrderGetInteger(ORDER_MAGIC) == InpMagic) return;
     }

   int dir = g_setup.dir;
   double impHigh = g_setup.impHigh, impLow = g_setup.impLow;
   if(impHigh - impLow <= 0.0) { ResetSetup(); return; }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return;
   double price = (dir > 0 ? ask : bid);

   // --- session, en heure LOCALE europeenne -----------------------
   if(!InSessionLocal(TimeCurrent()))
     {
      s_rejSession++;
      if(InpSessionMode == SESS_HARD)
        {
         Log(StringFormat("Setup rejete : hors session (%s local).",
                          TimeToString(ServerToLocalEU(TimeCurrent()), TIME_MINUTES)));
         ResetSetup();
        }
      return;
     }

   // --- ATR D1 : indispensable pour mettre le stop a l'echelle ----
   double atrD1 = ATRValue(hATRD1);
   double atrH4 = ATRValue(hATR);
   if(atrD1 <= 0.0)
     {
      s_noATR++;
      Log("ATR D1 indisponible : entree refusee. Un stop qu'on ne peut pas mettre a l'echelle n'est pas un stop.");
      return;   // setup conserve, nouvelle tentative a la prochaine confirmation
     }

   double entryLvl = FibLevel(dir, impHigh, impLow, InpEntryFib);
   bool inZone = (dir > 0 ? (price <= entryLvl) : (price >= entryLvl));
   bool market = false;
   double entryPrice = entryLvl;

   if(InpEntryTrigger == TRIG_MARKET_ZONE)
     {
      if(!inZone) { s_outOfZone++; return; }
      market = true; entryPrice = price;
     }
   else if(InpEntryTrigger == TRIG_MARKET_ANY)
     {
      market = true; entryPrice = price;
     }
   else if(inZone)
     {
      if(InpEntryMode == ENTRY_MARKET_OK) { market = true; entryPrice = price; }
      else { Log("Zone deja depassee (mode limite seule) : setup abandonne."); ResetSetup(); return; }
     }

   // --- stop loss structurel --------------------------------------
   double fibSL = FibLevel(dir, impHigh, impLow, InpSLFib);
   double extSL = (dir > 0 ? impLow : impHigh);
   double buf   = InpSLBufferATR * atrD1;
   double sl;

   if(InpSLMode == SLMODE_FIB)          sl = fibSL;
   else if(InpSLMode == SLMODE_EXTREME) sl = extSL;
   else                                 sl = (dir > 0 ? MathMin(fibSL, extSL) : MathMax(fibSL, extSL));

   sl = (dir > 0 ? sl - buf : sl + buf);

   // --- ecretage, entierement en multiples d'ATR D1 ---------------
   double structDist = MathAbs(entryPrice - sl);
   double floorD     = InpSLFloorATR * atrD1;
   double capD       = InpSLCapATR   * atrD1;
   double dist       = structDist;

   if(dist < floorD) { dist = floorD; s_clampFloor++; }
   if(dist > capD)   { dist = capD;   s_clampCap++;   }

   sl = (dir > 0 ? entryPrice - dist : entryPrice + dist);

   // --- niveau de stop minimal impose par le courtier -------------
   int stopsLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStop = stopsLvl * Pt();
   if(minStop > 0.0 && dist < minStop)
     {
      s_clampStops++;
      sl = (dir > 0 ? entryPrice - minStop * 1.5 : entryPrice + minStop * 1.5);
      dist = MathAbs(entryPrice - sl);
     }

   if(!market && minStop > 0.0 && MathAbs(price - entryPrice) < minStop)
     { market = true; entryPrice = price; }

   // --- contexte conserve pour le CSV -----------------------------
   g_entryATRD1  = atrD1;
   g_entryATRH4  = atrH4;
   g_entryRange  = impHigh - impLow;
   g_entrySpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   // --- diagnostic d'echelle, une seule fois ----------------------
   if(!g_scalePrinted)
     {
      g_scalePrinted = true;
      PrintFormat("=== CONTROLE D'ECHELLE (premier trade) ===");
      PrintFormat("  _Point %.5f | _Digits %d | prix %.*f", _Point, _Digits, _Digits, entryPrice);
      PrintFormat("  ATR D1(%d) ........ %.2f $ = %.3f %% du prix",
                  InpATRFilterPeriod, atrD1, 100.0 * atrD1 / entryPrice);
      PrintFormat("  SL structurel ..... %.2f $ = %.3f %% = %.3f x ATR",
                  structDist, 100.0 * structDist / entryPrice, structDist / atrD1);
      PrintFormat("  Plancher .......... %.2f $ = %.3f %% = %.2f x ATR",
                  floorD, 100.0 * floorD / entryPrice, InpSLFloorATR);
      PrintFormat("  Plafond ........... %.2f $ = %.3f %% = %.2f x ATR",
                  capD, 100.0 * capD / entryPrice, InpSLCapATR);
      PrintFormat("  SL retenu ......... %.2f $ = %.3f %% = %.3f x ATR",
                  dist, 100.0 * dist / entryPrice, dist / atrD1);
      PrintFormat("  Spread au moment de l'entree : %.0f points = %.2f $",
                  g_entrySpread, g_entrySpread * Pt());
      PrintFormat("  Si le SL retenu colle au plancher ou au plafond, le stop");
      PrintFormat("  structurel ne sert a rien : verifier l'entonnoir en fin de test.");
     }

   double score   = g_setup.score;
   double riskPct = RiskFromScore(score);

   if(PlaceLegs(dir, entryPrice, sl, market, score, riskPct, impHigh, impLow))
      g_setup.ordersPlaced = true;
  }

//==================================================================
//  NOUVELLE BARRE H4
//==================================================================
void OnNewH4Bar()
  {
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int size = CopyRates(_Symbol, PERIOD_H4, 1, InpH4Lookback, r);
   if(size < InpSwingBars * 4 + 10) return;

   if(g_setup.active)
     {
      g_setup.h4Elapsed++;
      if(g_setup.h4Elapsed > InpSetupExpiryBarsH4 && !g_setup.ordersPlaced)
        { s_setupExpired++; Log("Setup perime (H4)."); ResetSetup(); }
      else if(!g_setup.ordersPlaced)
        {
         double c = r[size-1].close;
         if(g_setup.dir > 0 && c < g_setup.impLow)  { s_invalid++; Log("Setup long invalide.");  ResetSetup(); }
         if(g_setup.dir < 0 && c > g_setup.impHigh) { s_invalid++; Log("Setup short invalide."); ResetSetup(); }
        }
     }

   if(g_setup.active && !g_setup.counterOK && !g_setup.ordersPlaced)
     {
      MqlRates last = r[size-1];
      bool counter = (g_setup.dir > 0) ? (last.close < last.open) : (last.close > last.open);
      if(!InpUseCounterCandle) counter = true;
      if(counter)
        {
         s_counterOK++;
         g_setup.counterOK = true;
         g_setup.h1Count   = 0;
         g_setup.h1Elapsed = 0;
         Log(StringFormat("Bougie contre-tendance validee (%s).", TimeToString(last.time)));
        }
      else if(g_setup.h4Elapsed > InpCounterMaxBarsH4)
        { s_counterKO++; Log("Pas de bougie contre-tendance dans le delai."); ResetSetup(); }
     }

   if(g_setup.active) return;

   int dir, cnt, firstBar, lastBar;
   if(!ScanStructure(r, size, dir, cnt, firstBar, lastBar)) return;
   if(cnt < InpBreaksRequired) return;

   datetime tBreak = r[lastBar].time;
   if(tBreak == g_lastArmedBreak) return;

   int age = (size - 1) - lastBar;
   if(age > InpSetupExpiryBarsH4) return;

   double impHigh, impLow;
   bool ok;
   if(InpImpulseMode == IMP_LAST_LEG)
      ok = BuildImpulseLastLeg(r, size, dir, lastBar, impHigh, impLow);
   else
      ok = BuildImpulseFullSeq(r, size, dir, firstBar, impHigh, impLow);
   if(!ok) return;

   double px = r[size-1].close;
   if(InpMaxRangePct > 0.0 && px > 0.0)
     {
      double rngPct = 100.0 * (impHigh - impLow) / px;
      if(rngPct > InpMaxRangePct)
        {
         s_rejRange++;
         g_lastArmedBreak = tBreak;
         Log(StringFormat("Setup rejete : amplitude %.2f%% > %.2f%%", rngPct, InpMaxRangePct));
         return;
        }
     }

   // --- sens autorise --------------------------------------------
   if((dir > 0 && !InpTradeLong) || (dir < 0 && !InpTradeShort))
     {
      s_rejDir++;
      g_lastArmedBreak = tBreak;
      return;
     }

   // --- filtre Ichimoku H4 ---------------------------------------
   int kumo = KumoState();
   g_entryKumo = (double)kumo;
   if(InpKumoMode != KUMO_OFF && kumo != 99)
     {
      bool rejected = false;
      if(InpKumoMode == KUMO_PRO_IN)
        {
         if(dir > 0 && kumo == -1) rejected = true;
         if(dir < 0 && kumo ==  1) rejected = true;
        }
      else
        {
         if(dir > 0 && kumo !=  1) rejected = true;
         if(dir < 0 && kumo != -1) rejected = true;
        }
      if(rejected)
        {
         s_rejKumo++;
         g_lastArmedBreak = tBreak;
         Log(StringFormat("Setup rejete : Ichimoku (sens %d, nuage %d)", dir, kumo));
         return;
        }
     }

   double score = TrendScore(dir);
   if(InpMinTrendScore > 0.0 && score < InpMinTrendScore)
     {
      s_rejScore++;
      g_lastArmedBreak = tBreak;
      Log(StringFormat("Setup rejete : note %.0f < %.0f", score, InpMinTrendScore));
      return;
     }

   ResetSetup();
   s_armed++;
   g_setup.active    = true;
   g_setup.dir       = dir;
   g_setup.tBreak    = tBreak;
   g_setup.impHigh   = impHigh;
   g_setup.impLow    = impLow;
   g_setup.score     = score;
   g_setup.h4Elapsed = age;
   g_lastArmedBreak  = tBreak;

   Log(StringFormat("SETUP ARME %s | %d cassures | impulsion %.*f - %.*f (%.2f%%) | note %.0f",
                    (dir > 0 ? "LONG" : "SHORT"), cnt, _Digits, impLow, _Digits, impHigh,
                    (px > 0 ? 100.0 * (impHigh - impLow) / px : 0.0), score));
  }

//==================================================================
//  NOUVELLE BARRE H1
//==================================================================
void OnNewH1Bar()
  {
   if(InpCancelPendingWE)
     {
      MqlDateTime d;
      TimeToStruct(TimeCurrent(), d);
      if(d.day_of_week == 5 && d.hour >= InpFridayCancelHour)
        {
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            ulong tk = OrderGetTicket(i);
            if(tk == 0) continue;
            if(OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
            trade.OrderDelete(tk);
            Log("Ordre en attente annule avant le week-end.");
           }
        }
     }

   if(!g_setup.active || g_setup.ordersPlaced) return;
   if(!g_setup.counterOK) return;

   MqlRates r[];
   ArraySetAsSeries(r, false);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 3, r) < 1) return;
   MqlRates last = r[ArraySize(r) - 1];
   if(last.time <= g_setup.tLastH1) return;
   g_setup.tLastH1 = last.time;

   g_setup.h1Elapsed++;
   if(g_setup.h1Elapsed > InpH1ConfirmMaxBars)
     { s_confirmKO++; Log("Confirmation H1 non obtenue dans le delai."); ResetSetup(); return; }

   bool good = (g_setup.dir > 0) ? (last.close > last.open) : (last.close < last.open);
   if(good) g_setup.h1Count++;
   else     g_setup.h1Count = 0;

   if(g_setup.h1Count >= InpH1ConfirmBars)
     {
      s_confirm++;
      Log(StringFormat("Confirmation H1 : %d bougies %s.", g_setup.h1Count,
                       (g_setup.dir > 0 ? "vertes" : "rouges")));
      TryEnter();
     }
  }

//==================================================================
//  GESTION DES POSITIONS
//==================================================================
void ManagePositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string cmt = PositionGetString(POSITION_COMMENT);
      bool legB; double rDist; double sc;
      int idx = TrackFind(tk);

      if(idx >= 0) { legB = g_track[idx].legB; rDist = g_track[idx].rDist; }
      else if(ParseComment(cmt, legB, rDist, sc))
        {
         int dirp = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
         TrackAdd(tk, dirp, PositionGetDouble(POSITION_PRICE_OPEN), rDist, legB,
                  g_setup.score, 0.0, g_setup.impHigh, g_setup.impLow);
         idx = TrackFind(tk);
        }
      else continue;

      if(rDist <= 0.0) continue;

      int dir      = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      double px    = (dir > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
      if(px <= 0.0) continue;

      double profitR = dir * (px - entry) / rDist;

      if(idx >= 0 && g_track[idx].excIdx >= 0)
        {
         int ei = g_track[idx].excIdx;
         if(profitR > e_mfe[ei]) e_mfe[ei] = profitR;
         if(profitR < e_mae[ei]) e_mae[ei] = profitR;
        }

      if(!legB) continue;
      double newSL = curSL;

      if(InpBEafterTP1 && idx >= 0 && !g_track[idx].beDone && InpTP1_R > 0.0 && profitR >= InpTP1_R)
        {
         double be = entry + dir * InpBEBufferR * rDist;
         if((dir > 0 && be > newSL) || (dir < 0 && (newSL == 0.0 || be < newSL)))
           { newSL = be; g_track[idx].beDone = true; }
        }

      // Suiveur. InpTrailStepR = 0 reproduit exactement l'ancien
      // comportement (un modify par amelioration, aussi minuscule
      // soit-elle). Une valeur > 0 impose un pas minimal et divise
      // le nombre de requetes serveur par plusieurs ordres de
      // grandeur : indispensable en reel, sans effet mesurable sur
      // le resultat si le pas reste petit.
      if(profitR >= InpTrailStartR)
        {
         double trail   = px - dir * InpTrailDistR * rDist;
         double minMove = InpTrailStepR * rDist;
         if(dir > 0 && trail > newSL + minMove) newSL = trail;
         if(dir < 0 && (newSL == 0.0 || trail < newSL - minMove)) newSL = trail;
        }

      if(newSL > 0.0 && MathAbs(newSL - curSL) > Pt() * 0.5)
        {
         int stopsLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minStop = stopsLvl * Pt();
         bool ok = (dir > 0) ? (px - newSL > minStop) : (newSL - px > minStop);
         if(ok) trade.PositionModify(tk, NP(newSL), curTP);
        }
     }
  }

//==================================================================
//  CSV + BILAN
//==================================================================
void WriteCSVFromHistory()
  {
   if(!HistorySelect(0, TimeCurrent() + 86400))
     { Print("Bilan : historique indisponible."); return; }

   int total = HistoryDealsTotal();
   if(total <= 0) { Print("Bilan : aucune transaction."); return; }

   ulong    idIn[];   ArrayResize(idIn,    total);
   double   pxIn[];   ArrayResize(pxIn,    total);
   long     tmIn[];   ArrayResize(tmIn,    total);
   double   rdIn[];   ArrayResize(rdIn,    total);
   double   scIn[];   ArrayResize(scIn,    total);
   int      lgIn[];   ArrayResize(lgIn,    total);
   int      dirIn[];  ArrayResize(dirIn,   total);
   double   volIn[];  ArrayResize(volIn,   total);
   double   cmIn[];   ArrayResize(cmIn,    total);
   int nIn = 0;

   for(int i = 0; i < total; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;

      bool legB; double rDist, score;
      if(!ParseComment(HistoryDealGetString(tk, DEAL_COMMENT), legB, rDist, score)) continue;

      idIn[nIn]  = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
      pxIn[nIn]  = HistoryDealGetDouble(tk, DEAL_PRICE);
      tmIn[nIn]  = HistoryDealGetInteger(tk, DEAL_TIME);
      rdIn[nIn]  = rDist;
      scIn[nIn]  = score;
      lgIn[nIn]  = (legB ? 1 : 0);
      dirIn[nIn] = (HistoryDealGetInteger(tk, DEAL_TYPE) == DEAL_TYPE_BUY ? 1 : -1);
      volIn[nIn] = HistoryDealGetDouble(tk, DEAL_VOLUME);
      cmIn[nIn]  = HistoryDealGetDouble(tk, DEAL_COMMISSION);
      nIn++;
     }

   int h = INVALID_HANDLE;
   if(InpWriteCSV)
     {
      h = FileOpen(InpCSVName, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');
      if(h == INVALID_HANDLE)
         Print("CSV : ouverture impossible (", GetLastError(), ")");
      else
         FileWrite(h, "time_in", "time_out", "leg", "dir", "entry", "vol", "sl_pts", "sl_dollars",
                   "sl_pct", "sl_atr_d1", "exit", "R_brut", "R_net", "profit", "swap", "commission",
                   "score", "duration_h", "atr_d1", "atr_h4", "range_pts", "range_atr", "kumo",
                   "MFE_R", "MAE_R", "year", "hour_local", "block", "spread_pts");
     }

   int written = 0;
   long nJour=0, nSoir=0, nNuit=0;
   double rbJour=0, rbSoir=0, rbNuit=0;
   double rnJour=0, rnSoir=0, rnNuit=0;
   double sumRbrut=0, sumRnet=0, sumSwapR=0, sumCommR=0, sumRisk=0, sumHold=0;
   double sumSwapCcy=0, sumCommCcy=0, sumProfitCcy=0;
   int    nTr=0, nMFE2=0;

   for(int i = 0; i < total; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      ulong pid = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
      int k = -1;
      for(int j = 0; j < nIn; j++)
         if(idIn[j] == pid) { k = j; break; }
      if(k < 0) continue;

      double exitPx = HistoryDealGetDouble(tk, DEAL_PRICE);
      double gross  = HistoryDealGetDouble(tk, DEAL_PROFIT);
      double swap   = HistoryDealGetDouble(tk, DEAL_SWAP);
      double comm   = cmIn[k] + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      long   tOut   = HistoryDealGetInteger(tk, DEAL_TIME);

      int ei = ExcFind(pid);
      double aD1 = (ei >= 0 ? e_atrD1[ei]  : 0.0);
      double aH4 = (ei >= 0 ? e_atrH4[ei]  : 0.0);
      double rng = (ei >= 0 ? e_range[ei]  : 0.0);
      double kum = (ei >= 0 ? e_kumo[ei]   : 99.0);
      double mfe = (ei >= 0 ? e_mfe[ei]    : 0.0);
      double mae = (ei >= 0 ? e_mae[ei]    : 0.0);
      double spd = (ei >= 0 ? e_spread[ei] : 0.0);
      double slAtr  = (aD1 > 0.0 ? rdIn[k] / aD1 : 0.0);
      double rngAtr = (aD1 > 0.0 ? rng     / aD1 : 0.0);

      double Rbrut = (rdIn[k] > 0.0 ? dirIn[k] * (exitPx - pxIn[k]) / rdIn[k] : 0.0);
      double risk  = LossPerLot(rdIn[k]) * volIn[k];          // valeur de 1 R, en devise
      double Rnet  = (risk > 0.0 ? (gross + swap + comm) / risk : 0.0);
      double swapR = (risk > 0.0 ? swap / risk : 0.0);
      double commR = (risk > 0.0 ? comm / risk : 0.0);
      double slPct = (pxIn[k] > 0.0 ? 100.0 * rdIn[k] / pxIn[k] : 0.0);
      double durH  = (double)(tOut - tmIn[k]) / 3600.0;

      datetime tLoc = ServerToLocalEU((datetime)tmIn[k]);
      MqlDateTime dl;
      TimeToStruct(tLoc, dl);
      double hLoc = (double)dl.hour + (double)dl.min / 60.0;
      string blk  = BlockName((datetime)tmIn[k]);

      if(lgIn[k] == 1 || InpTP1_R <= 0.0)
        {
         nTr++;
         sumRbrut += Rbrut; sumRnet += Rnet;
         sumSwapR += swapR; sumCommR += commR;
         sumRisk  += risk;  sumHold += durH;
         sumSwapCcy += swap; sumCommCcy += comm; sumProfitCcy += (gross + swap + comm);
         if(mfe >= 2.0) nMFE2++;
         if(blk == "JOUR")      { nJour++; rbJour += Rbrut; rnJour += Rnet; }
         else if(blk == "SOIR") { nSoir++; rbSoir += Rbrut; rnSoir += Rnet; }
         else                   { nNuit++; rbNuit += Rbrut; rnNuit += Rnet; }
        }

      if(h != INVALID_HANDLE)
         FileWrite(h,
                   TimeToString((datetime)tmIn[k], TIME_DATE | TIME_MINUTES),
                   TimeToString((datetime)tOut,    TIME_DATE | TIME_MINUTES),
                   (lgIn[k] == 1 ? "B" : "A"),
                   (dirIn[k] > 0 ? "LONG" : "SHORT"),
                   DoubleToString(pxIn[k], _Digits),
                   DoubleToString(volIn[k], 2),
                   DoubleToString(rdIn[k] / Pt(), 0),
                   DoubleToString(rdIn[k], 2),
                   DoubleToString(slPct, 3),
                   DoubleToString(slAtr, 3),
                   DoubleToString(exitPx, _Digits),
                   DoubleToString(Rbrut, 4),
                   DoubleToString(Rnet, 4),
                   DoubleToString(gross, 2),
                   DoubleToString(swap, 2),
                   DoubleToString(comm, 2),
                   DoubleToString(scIn[k], 0),
                   DoubleToString(durH, 1),
                   DoubleToString(aD1, 2),
                   DoubleToString(aH4, 2),
                   DoubleToString(rng / Pt(), 0),
                   DoubleToString(rngAtr, 3),
                   DoubleToString(kum, 0),
                   DoubleToString(mfe, 3),
                   DoubleToString(mae, 3),
                   IntegerToString(dl.year),
                   DoubleToString(hLoc, 2),
                   blk,
                   DoubleToString(spd, 0));
      written++;
     }

   if(h != INVALID_HANDLE)
     {
      FileClose(h);
      PrintFormat("CSV : %d jambes ecrites dans le dossier COMMUN -> %s", written, InpCSVName);
      Print("Chemin : ...\\MetaQuotes\\Terminal\\Common\\Files\\", InpCSVName);
     }

   if(nTr <= 0) return;

   PrintFormat("=== BILAN EN R ===");
   PrintFormat("Trades ..................... %d", nTr);
   PrintFormat("Valeur moyenne de 1 R ...... %.2f (devise du compte)", sumRisk / nTr);
   PrintFormat("Tenue moyenne .............. %.1f h", sumHold / nTr);
   PrintFormat("R BRUT (prix seul) ......... %+.2f R   (%+.3f R/trade)", sumRbrut, sumRbrut / nTr);
   PrintFormat("  - swap ................... %+.2f R   (%+.2f devise)", sumSwapR, sumSwapCcy);
   PrintFormat("  - commission ............. %+.2f R   (%+.2f devise)", sumCommR, sumCommCcy);
   PrintFormat("R NET ...................... %+.2f R   (%+.3f R/trade, %+.2f devise)",
               sumRnet, sumRnet / nTr, sumProfitCcy);
   PrintFormat("P(MFE >= 2R) ............... %.1f %%   [marche aleatoire = 33.3 %%]",
               100.0 * (double)nMFE2 / (double)nTr);
   PrintFormat("  Sous 33.3 %%, l'ENTREE n'apporte pas d'information : le");
   PrintFormat("  resultat vient du suiveur et de la modulation du risque.");

   PrintFormat("=== VENTILATION PAR BLOC (heure locale EU) ===");
   PrintFormat("JOUR 08:00-17:30 ... %I64d tr | brut %+.2f R | NET %+.2f R | %+.3f R/tr net",
               nJour, rbJour, rnJour, (nJour > 0 ? rnJour / (double)nJour : 0.0));
   PrintFormat("SOIR 17:30-23:30 ... %I64d tr | brut %+.2f R | NET %+.2f R | %+.3f R/tr net",
               nSoir, rbSoir, rnSoir, (nSoir > 0 ? rnSoir / (double)nSoir : 0.0));
   PrintFormat("NUIT 23:30-08:00 ... %I64d tr | brut %+.2f R | NET %+.2f R | %+.3f R/tr net",
               nNuit, rbNuit, rnNuit, (nNuit > 0 ? rnNuit / (double)nNuit : 0.0));
   PrintFormat("RAPPEL : un bloc a moins de 30 trades ne prouve rien.");
  }

//==================================================================
//  EVENEMENTS
//==================================================================
int OnInit()
  {
   // --- garde-fou de coherence : un plancher au-dessus du plafond
   //     ecrase silencieusement tout le stop structurel. C'est
   //     exactement ce qui s'est produit en v1.17.
   if(InpSLFloorATR >= InpSLCapATR)
     {
      PrintFormat("ERREUR : plancher de SL (%.2f x ATR) >= plafond (%.2f x ATR).",
                  InpSLFloorATR, InpSLCapATR);
      PrintFormat("Dans cette configuration, le plafond ecrase le plancher et TOUS");
      PrintFormat("les stops valent exactement le plafond. Le stop structurel ne");
      PrintFormat("sert plus a rien. Demarrage refuse.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpSLFloorATR <= 0.0 || InpSLCapATR <= 0.0)
     {
      Print("ERREUR : plancher et plafond de SL doivent etre > 0. Demarrage refuse.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   hMAFast = iMA (_Symbol, PERIOD_H4, InpMAFast, 0, InpMAMethod, PRICE_CLOSE);
   hMASlow = iMA (_Symbol, PERIOD_H4, InpMASlow, 0, InpMAMethod, PRICE_CLOSE);
   hATR    = iATR(_Symbol, PERIOD_H4, InpATRPeriod);
   hATRD1  = iATR(_Symbol, PERIOD_D1, InpATRFilterPeriod);
   hIchi   = iIchimoku(_Symbol, PERIOD_H4, InpTenkan, InpKijun, InpSenkou);
   if(hMAFast == INVALID_HANDLE || hMASlow == INVALID_HANDLE || hATR == INVALID_HANDLE
      || hATRD1 == INVALID_HANDLE || hIchi == INVALID_HANDLE)
     { Print("ERREUR : creation des indicateurs impossible."); return INIT_FAILED; }

   long expMode = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
   g_expirationOK = ((expMode & SYMBOL_EXPIRATION_SPECIFIED) != 0);
   if(!g_expirationOK)
      Print("AVERTISSEMENT : ORDER_TIME_SPECIFIED non supporte, annulation manuelle des attentes.");

   ResetSetup();
   g_trackN = 0;
   e_n      = 0;
   g_scalePrinted = false;

   PrintFormat("=== CHOCH_XAU_EA v1.18 — STOPS A L'ECHELLE DE L'ATR ===");
   PrintFormat("Symbole %s | Point %.5f | Digits %d | contrat %.0f",
               _Symbol, _Point, _Digits, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
   PrintFormat("Courtier %s | devise %s | levier 1:%d",
               AccountInfoString(ACCOUNT_COMPANY), AccountInfoString(ACCOUNT_CURRENCY),
               (int)AccountInfoInteger(ACCOUNT_LEVERAGE));
   PrintFormat("Impulsion : %s", (InpImpulseMode == IMP_LAST_LEG ? "DERNIERE JAMBE" : "SEQUENCE COMPLETE"));
   string trg = "LIMITE au fib";
   if(InpEntryTrigger == TRIG_MARKET_ZONE) trg = "MARCHE si en zone";
   if(InpEntryTrigger == TRIG_MARKET_ANY)  trg = "MARCHE, zone ignoree";
   PrintFormat("Declenchement : %s | cassures %d | fractale H4 %d",
               trg, InpBreaksRequired, InpSwingBars);
   PrintFormat("STOP : fib %.2f, mode %d, tampon %.2f x ATR | plancher %.2f x ATR | plafond %.2f x ATR",
               InpSLFib, (int)InpSLMode, InpSLBufferATR, InpSLFloorATR, InpSLCapATR);
   PrintFormat("  Aucun parametre de stop en points ni en %% du prix : le reglage");
   PrintFormat("  est transposable d'un courtier a l'autre quel que soit _Point.");
   PrintFormat("Risque %.2f-%.2f%% | TP1 %.2fR | suiveur %.2fR/%.2fR | pas %.2fR | BE %s",
               InpRiskTotalMin, InpRiskTotalMax, InpTP1_R, InpTrailStartR, InpTrailDistR,
               InpTrailStepR, (InpBEafterTP1 ? "OUI" : "NON"));
   if(InpTrailStepR <= 0.0)
      PrintFormat("  Pas du suiveur a 0 : un modify par amelioration, meme minuscule.");
   PrintFormat("Sens autorises : achats %s / ventes %s",
               (InpTradeLong ? "OUI" : "NON"), (InpTradeShort ? "OUI" : "NON"));
   string km = "INACTIF";
   if(InpKumoMode == KUMO_PRO_IN) km = "PRO-TENDANCE + INTERIEUR DU NUAGE";
   if(InpKumoMode == KUMO_STRICT) km = "STRICT";
   PrintFormat("Filtre Ichimoku H4 : %s  (%d/%d/%d)", km, InpTenkan, InpKijun, InpSenkou);

   string sm = "24h";
   if(InpSessionMode == SESS_HARD)  sm = "FENETRE, rejet franc";
   if(InpSessionMode == SESS_DEFER) sm = "FENETRE, report (diagnostic)";
   PrintFormat("SESSION : %s", sm);
   if(InpSessionMode != SESS_OFF)
      PrintFormat("  Fenetre %02d:%02d - %02d:%02d en heure LOCALE europeenne",
                  InpLocalStartHour, InpLocalStartMin, InpLocalEndHour, InpLocalEndMin);
   PrintFormat("  Serveur GMT+%d en hiver, regle DST %s",
               InpServerGMTWinter,
               (InpServerDST == DST_US ? "AMERICAINE" : (InpServerDST == DST_EU ? "EUROPEENNE" : "AUCUNE")));
   PrintFormat("  CONTROLE : serveur %s  ->  local %s  (ecart attendu 1 h)",
               TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
               TimeToString(ServerToLocalEU(TimeCurrent()), TIME_DATE | TIME_MINUTES));
   PrintFormat("  Verifier cette ligne en JANVIER ET EN JUILLET.");

   return INIT_SUCCEEDED;
  }

//------------------------------------------------------------------
void OnDeinit(const int reason)
  {
   PrintFormat("=== ENTONNOIR ===");
   PrintFormat("Setups armes .............. %I64d", s_armed);
   PrintFormat("  rejetes (note) .......... %I64d", s_rejScore);
   PrintFormat("  rejetes (amplitude) ..... %I64d", s_rejRange);
   PrintFormat("Bougie contre-tendance OK . %I64d  (echecs %I64d)", s_counterOK, s_counterKO);
   PrintFormat("Confirmations H1 .......... %I64d  (echecs %I64d)", s_confirm, s_confirmKO);
   PrintFormat("Jeux d'ordres poses ....... %I64d  (marche %I64d / limite %I64d)", s_placed, s_market, s_limit);
   PrintFormat("  echecs d'envoi .......... %I64d  (dont marche ferme %I64d)", s_sendFail, s_marketClosed);
   PrintFormat("  volume nul .............. %I64d  | volume plafonne %I64d", s_volZero, s_capped);
   PrintFormat("Confirmations hors zone ... %I64d", s_outOfZone);
   PrintFormat("Rejetes par Ichimoku ...... %I64d", s_rejKumo);
   PrintFormat("Rejetes par le sens ....... %I64d", s_rejDir);
   PrintFormat("Rejetes par la SESSION .... %I64d", s_rejSession);
   PrintFormat("Refuses : ATR D1 absent ... %I64d", s_noATR);
   PrintFormat("Setups perimes / invalides  %I64d / %I64d", s_setupExpired, s_invalid);
   PrintFormat("POSITIONS REMPLIES ........ %I64d", s_filled);

   PrintFormat("=== ECRETAGE DU STOP  (LE CONTROLE QUI MANQUAIT) ===");
   double np = (double)MathMax(s_placed, 1);
   PrintFormat("SL ramene au PLANCHER ..... %I64d  (%.1f %% des trades)", s_clampFloor, 100.0 * s_clampFloor / np);
   PrintFormat("SL ramene au PLAFOND ...... %I64d  (%.1f %% des trades)", s_clampCap,   100.0 * s_clampCap   / np);
   PrintFormat("SL elargi (stops level) ... %I64d", s_clampStops);
   if(100.0 * (s_clampFloor + s_clampCap) / np > 50.0)
     {
      PrintFormat("ALERTE : plus de la moitie des stops sont ecretes. Le stop");
      PrintFormat("structurel (fib / extreme d'impulsion) ne pilote plus rien.");
      PrintFormat("Elargir la bande plancher-plafond avant d'interpreter ce run.");
     }

   if(hMAFast != INVALID_HANDLE) IndicatorRelease(hMAFast);
   if(hMASlow != INVALID_HANDLE) IndicatorRelease(hMASlow);
   if(hATR    != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hATRD1  != INVALID_HANDLE) IndicatorRelease(hATRD1);
   if(hIchi   != INVALID_HANDLE) IndicatorRelease(hIchi);

   WriteCSVFromHistory();
  }

//------------------------------------------------------------------
void OnTick()
  {
   ManagePositions();
   TrackPurge();

   datetime t4 = iTime(_Symbol, PERIOD_H4, 0);
   if(t4 != g_lastH4Bar && t4 > 0) { g_lastH4Bar = t4; OnNewH4Bar(); }

   datetime t1 = iTime(_Symbol, PERIOD_H1, 0);
   if(t1 != g_lastH1Bar && t1 > 0) { g_lastH1Bar = t1; OnNewH1Bar(); }

   if(g_setup.active && g_setup.ordersPlaced)
     {
      bool any = false;
      for(int i = PositionsTotal() - 1; i >= 0 && !any; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(tk > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagic) any = true;
        }
      for(int i = OrdersTotal() - 1; i >= 0 && !any; i--)
        {
         ulong tk = OrderGetTicket(i);
         if(tk > 0 && OrderGetInteger(ORDER_MAGIC) == InpMagic) any = true;
        }
      if(!any) ResetSetup();
     }
  }

//------------------------------------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;

   long entryType = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong posID    = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

   if(entryType == DEAL_ENTRY_IN)
     {
      s_filled++;
      if(TrackFind(posID) >= 0) return;
      string cmt = HistoryDealGetString(trans.deal, DEAL_COMMENT);
      bool legB; double rDist, sc;
      if(!ParseComment(cmt, legB, rDist, sc)) return;
      long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
      int dir = (dtype == DEAL_TYPE_BUY ? 1 : -1);
      TrackAdd(posID, dir, HistoryDealGetDouble(trans.deal, DEAL_PRICE), rDist, legB,
               g_setup.score, RiskFromScore(g_setup.score), g_setup.impHigh, g_setup.impLow);
      return;
     }
  }
//+------------------------------------------------------------------+
