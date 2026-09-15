//+------------------------------------------------------------------+
//|                                        CHOCH_XAU_EA_v118_ICM.mq5 |
//|                                                                  |
//|  Code C — Double CHOCH H4 + filtre 2 MM + Discount/Premium       |
//|  v1.18 — VERSION IC MARKETS : STOPS A L'ECHELLE DE L'ATR         |
//|  v1.18.1 — FIABILISATION TECHNIQUE (aucun changement de          |
//|            strategie, voir le bloc "v1.18.1" plus bas)           |
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
//|  CE QUI CHANGE (v1.18)                                           |
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
//|  v1.18.1 — FIABILISATION TECHNIQUE                               |
//|                                                                  |
//|  OBJECTIF : que le backtest MESURE la strategie, pas des         |
//|  artefacts techniques. Aucune regle CHOCH, pivot, filtre,        |
//|  entree, SL/TP ou suiveur n'est modifiee. Aucun parametre par    |
//|  defaut de strategie n'est modifie.                              |
//|                                                                  |
//|  C1  Cap ATR vs STOPS_LEVEL : l'elargissement impose par le      |
//|      courtier ne peut plus faire sortir le SL de la bande        |
//|      [plancher ; plafond]. Si minStop > plafond, le trade est    |
//|      REFUSE (compteur REJECT_STOPS_VS_CAP), setup conserve.      |
//|  C2  SLMODE_FURTHEST : comportement CONFIRME et DOCUMENTE, non   |
//|      modifie (voir commentaire dans ComputeStop).                |
//|  C3  Compteurs non ambigus : jeux d'ordres, ordres acceptes,     |
//|      positions ouvertes / fermees, deals d'entree / de sortie,   |
//|      fills partiels. "s_filled" n'existe plus.                   |
//|  C4  Risque monetaire MEMORISE a l'entree (tick size, tick       |
//|      value de perte, SL reel, prix reel). Le CSV n'utilise plus  |
//|      la valeur du symbole au moment du OnDeinit.                 |
//|  C5  Compte NETTING refuse a l'initialisation                    |
//|      ("ERROR: EA requires HEDGING account mode").                |
//|  C6  Un ticket = une seule entree de suivi (TrackFind avant      |
//|      TrackAdd, doublon journalise).                              |
//|  C7  InpUseCounterCandle=false : counterOK vrai des l'armement.  |
//|      => CHANGE LE TIMING d'entree dans ce mode uniquement        |
//|      (une H4 de retard artificiel supprimee). Mode par defaut    |
//|      (true) : strictement identique.                             |
//|  C8  Ichimoku : donnees absentes => setup NON ARME (fail-closed) |
//|      au lieu de passer le filtre. La cassure n'est pas consommee |
//|      : re-evaluation a la H4 suivante tant que age <= expiry.    |
//|  C9  Impulsion figee a tBreak : plus aucune barre posterieure a  |
//|      la cassure n'entre dans le calcul de impHigh/impLow ni      |
//|      dans la confirmation du pivot d'ancrage. Pour age = 0       |
//|      (cas courant) le resultat est identique a v1.18.            |
//|  C10 Invalidation du setup sur la CLOTURE H4 (close < impLow)    |
//|      : regle strategique, documentee, NON modifiee.              |
//|  C11 TRIG_LIMIT_FIB : la conversion limite -> marche a lieu      |
//|      AVANT le calcul du SL, qui est donc toujours calcule sur    |
//|      le prix d'entree reellement envoye.                         |
//|  C12 Fills partiels : agregation par DEAL_POSITION_ID (volume    |
//|      reellement execute, prix moyen pondere, N deals IN/OUT).    |
//|      Une ligne CSV = une position, jamais un deal.               |
//|  C13 R brut / R net calcules sur le risque memorise a l'entree.  |
//|  C14 Bilan : jambe A + jambe B + total, et R par setup           |
//|      (PnL des deux jambes / risque des deux jambes).             |
//|  C15 Session : compteur par setup ET compteur par tentative H1.  |
//|  C16 Suiveur : compteurs d'appels PositionModify (succes /       |
//|      echecs). Comportement du suiveur inchange.                  |
//|  C17 Slippage : InpSlippage est en POINTS (_Point). 30 points =  |
//|      0,30 $ sur XAUUSD 2 digits (IC Markets) mais 0,03 $ sur un  |
//|      XAUUSD 3 digits. Le parametre n'est PAS invariant           |
//|      d'echelle, contrairement aux stops. Valeur non modifiee ;   |
//|      son equivalent en $ et en ATR est journalise.               |
//|  C18 DST : diagnostic journalise (offsets, drapeaux DST, heure   |
//|      locale, bloc, session) a l'init, a chaque changement de     |
//|      mois et a chaque tentative d'entree. Logique inchangee.     |
//|  C19 Invariants de securite (InpDiagInvariants) : barre 0 jamais |
//|      utilisee, impulsion <= tBreak, SL du bon cote, SL dans la   |
//|      bande, SL >= stops level, volume <= max, risque <= risque   |
//|      calcule, pas de doublon de suivi, hedging, Ichimoku valide. |
//+------------------------------------------------------------------+
#property copyright "Code C"
#property link      ""
#property version   "1.181"
#property description "Double CHOCH H4 + 2 MM + confirmation H1 — stops a l'echelle de l'ATR (v1.18.1 fiabilisation)"

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
//  C17 — InpSlippage est exprime en POINTS du symbole (_Point), pas en
//  dollars ni en ATR. Sur XAUUSD a 2 decimales (IC Markets) 30 points
//  = 0,30 $. Sur un XAUUSD a 3 decimales le MEME reglage vaut 0,03 $,
//  soit 10x moins tolerant : plus de requotes / rejets en reel.
//  Valeur volontairement NON modifiee dans cette version ; l'equivalent
//  en $ et en multiple d'ATR D1 est imprime a l'init et au 1er trade.
input int             InpSlippage         = 30;     // Deviation autorisee (points, cf. C17)

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
input bool            InpDiagInvariants   = true;   // Controles d'invariants (C19), journalises

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
int      g_lastDiagMonth = -1;

// --- compteurs d'entonnoir (setups) ------------------------------
long s_armed=0, s_rejScore=0, s_rejRange=0, s_counterOK=0, s_counterKO=0;
long s_confirm=0, s_confirmKO=0, s_market=0, s_limit=0;
long s_sendFail=0, s_marketClosed=0;
long s_invalid=0, s_setupExpired=0, s_volZero=0, s_capped=0;
long s_outOfZone=0, s_rejKumo=0, s_rejDir=0;
long s_noATR=0, s_clampFloor=0, s_clampCap=0, s_clampStops=0;

// --- C3 : compteurs d'execution, non ambigus ---------------------
//  s_orderSets       : appels PlaceLegs ayant envoye au moins 1 ordre OK
//                      (= "jeux d'ordres", 1 par setup entre)
//  s_ordersPlaced    : ordres individuels acceptes par le serveur (A et B)
//  s_positionsOpened : identifiants de position DISTINCTS vus a l'entree
//  s_positionsClosed : positions dont le volume est integralement sorti
//  s_entryDeals      : deals DEAL_ENTRY_IN (>= positions si fills partiels)
//  s_exitDeals       : deals DEAL_ENTRY_OUT
//  s_partialFills    : deals IN qui ne remplissent pas l'ordre d'un coup
long s_orderSets=0, s_ordersPlaced=0, s_positionsOpened=0, s_positionsClosed=0;
long s_entryDeals=0, s_exitDeals=0, s_partialFills=0;
long s_tp1Hits=0, s_tp2Hits=0, s_slHits=0;

// --- C1 / C8 / C15 / C6 / C16 / C19 ------------------------------
long s_rejStopsVsCap=0;                  // REJECT_STOPS_VS_CAP
long s_rejIchimokuData=0;                // Ichimoku indisponible -> non arme
long s_setupRejectedSession=0;           // 1 par setup
long s_entryAttemptRejectedSession=0;    // 1 par tentative H1
long s_trackDuplicates=0;                // TrackAdd refuse (ticket deja suivi)
long s_positionModifyCalls=0, s_positionModifySuccess=0, s_positionModifyFailed=0;
long s_invariantFail=0;                  // invariants violes (C19)
long s_csvFallback=0;                    // positions sans risque memorise (CSV)

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
   bool     sessionRejCounted;   // C15
  };
SetupState g_setup;

datetime g_lastArmedBreak = 0;

// --- suivi des positions ouvertes (volatil, purge a la fermeture) -
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
   int      recIdx;
  };
PosTrack g_track[MAX_TRACK];
int      g_trackN = 0;

// --- C4 / C12 : fiche persistante par position ------------------
//  Conservee jusqu'a la fin du test. Memorise ce que le symbole
//  valait AU MOMENT DE L'ENTREE (tick size, tick value de perte),
//  le SL reellement envoye, et le contexte (ATR, kumo, spread...).
#define MAX_REC 8192
#define TICKSRC_NONE   0   // pas de fiche (fallback complet au CSV)
#define TICKSRC_LOSS   1   // SYMBOL_TRADE_TICK_VALUE_LOSS a l'entree
#define TICKSRC_VALUE  2   // SYMBOL_TRADE_TICK_VALUE a l'entree (fallback)
#define TICKSRC_RECOV  3   // position recuperee apres redemarrage : valeurs courantes
struct PosRec
  {
   ulong    id;
   int      dir;
   bool     legB;
   double   score;
   double   riskPct;
   datetime setupBreak;
   datetime tOpen;
   double   entryPlanned;
   double   slSent;
   double   rDistPlanned;
   double   volIn;          // volume execute cumule (deals IN vus en direct)
   int      nIn;
   int      nOut;
   double   tickSize;
   double   tickValue;
   int      tickSource;
   double   mfe;
   double   mae;
   double   atrD1;
   double   atrH4;
   double   range;
   double   kumo;
   double   spread;
   double   impHigh;
   double   impLow;
  };
PosRec   g_rec[MAX_REC];
int      g_recN = 0;

// --- contexte d'entree (copie dans la fiche a la creation) -------
double   g_entryATRD1 = 0.0, g_entryATRH4 = 0.0, g_entryRange = 0.0, g_entryKumo = 0.0;
double   g_entrySpread = 0.0;

//==================================================================
//  C19 — INVARIANTS
//==================================================================
void Invariant(const bool cond, const string what)
  {
   if(!InpDiagInvariants) return;
   if(cond) return;
   s_invariantFail++;
   PrintFormat("INVARIANT VIOLE [%I64d] : %s", s_invariantFail, what);
  }

//==================================================================
//  UTILITAIRES
//==================================================================
void Log(const string msg) { if(InpVerbose) Print(msg); }
double Pt() { return _Point; }
double NP(const double price) { return NormalizeDouble(price, _Digits); }

//------------------------------------------------------------------
//  C4 — valeur du tick pour une PERTE. TICK_VALUE_LOSS est la valeur
//  exacte utilisee par le serveur quand la position perd (cas du SL),
//  pour un achat comme pour une vente. Fallback : TICK_VALUE
//  (identique sur un compte USD pour XAUUSD, legerement different
//  sur un compte CHF/EUR). Retourne 0 si rien de fiable.
double TickValueForLoss(int &src)
  {
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv > 0.0) { src = TICKSRC_LOSS; return tv; }
   tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tv > 0.0) { src = TICKSRC_VALUE; return tv; }
   src = TICKSRC_NONE;
   return 0.0;
  }

double LossPerLotWith(const double slDistance, const double ts, const double tv)
  {
   if(ts <= 0.0 || tv <= 0.0) return 0.0;
   return (slDistance / ts) * tv;
  }

double LossPerLot(const double slDistance)
  {
   int src = TICKSRC_NONE;
   double tv = TickValueForLoss(src);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return LossPerLotWith(slDistance, ts, tv);
  }

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

   // C19 : le volume ne depasse jamais le maximum du symbole et la
   //       perte au SL ne depasse jamais le risque demande.
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   Invariant(vol <= vmax + 1e-9,
             StringFormat("volume %.2f > SYMBOL_VOLUME_MAX %.2f", vol, vmax));
   Invariant(vol * lpl <= risk * (1.0 + 1e-6) + 1e-6,
             StringFormat("perte au SL %.2f > risque demande %.2f", vol * lpl, risk));
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
//  C18 : logique NON modifiee ; validation a faire sur donnees IC
//  Markets reelles via les lignes "DST |" du journal.
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
//  C18 — diagnostic DST, une ligne
string DSTRuleName()
  {
   if(InpServerDST == DST_US) return "US";
   if(InpServerDST == DST_EU) return "EU";
   return "AUCUNE";
  }

string DSTDiag(const datetime tServer)
  {
   datetime tLoc = ServerToLocalEU(tServer);
   int offS = ServerOffsetGMT(tServer);
   int offL = 1 + (IsEU_DST(tServer) ? 1 : 0);
   return StringFormat("DST | serveur %s = GMT%+d (hiver GMT%+d, regle %s, US_DST=%d, EU_DST=%d) -> local EU %s = GMT%+d | bloc %s | session %s",
                       TimeToString(tServer, TIME_DATE | TIME_MINUTES), offS, InpServerGMTWinter, DSTRuleName(),
                       (IsUS_DST(tServer) ? 1 : 0), (IsEU_DST(tServer) ? 1 : 0),
                       TimeToString(tLoc, TIME_DATE | TIME_MINUTES), offL,
                       BlockName(tServer), (InSessionLocal(tServer) ? "DANS" : "HORS"));
  }

void PrintDSTTransitions(const int year)
  {
   PrintFormat("DST | transitions %d telles que calculees par l'EA (horodatage serveur) :", year);
   PrintFormat("DST |   US : debut %s  fin %s",
               TimeToString(NthSundayUTC(year, 3, 2, 7), TIME_DATE | TIME_MINUTES),
               TimeToString(NthSundayUTC(year, 11, 1, 6), TIME_DATE | TIME_MINUTES));
   PrintFormat("DST |   EU : debut %s  fin %s",
               TimeToString(LastSundayUTC(year, 3, 1), TIME_DATE | TIME_MINUTES),
               TimeToString(LastSundayUTC(year, 10, 1), TIME_DATE | TIME_MINUTES));
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
//  INDICATEURS (toujours barre 1 = derniere barre CLOSE)
//==================================================================
//  C8 — 99 = "donnee indisponible". Depuis v1.18.1 cette valeur
//  entraine le NON-armement du setup (fail-closed) au lieu de laisser
//  passer le filtre. La semantique des valeurs -1 / 0 / +1 et le
//  shift lu (barre 1, Senkou tel que calcule par iIchimoku, sans
//  correction de projection) sont volontairement INCHANGES.
int KumoState()
  {
   if(hIchi == INVALID_HANDLE) return 99;
   double a[1], b[1], c[1];
   if(CopyBuffer(hIchi, SENKOUSPANA_LINE, 1, 1, a) < 1) return 99;
   if(CopyBuffer(hIchi, SENKOUSPANB_LINE, 1, 1, b) < 1) return 99;
   if(CopyClose(_Symbol, PERIOD_H4, 1, 1, c) < 1)       return 99;
   if(a[0] == EMPTY_VALUE || b[0] == EMPTY_VALUE)       return 99;
   if(a[0] <= 0.0 || b[0] <= 0.0 || c[0] <= 0.0)        return 99;
   double top = MathMax(a[0], b[0]);
   double bot = MathMin(a[0], b[0]);
   if(c[0] > top) return  1;
   if(c[0] < bot) return -1;
   return 0;
  }

double ATRValue(const int handle)
  {
   double a[1];
   if(handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(handle, 0, 1, 1, a) < 1) return 0.0;
   if(a[0] == EMPTY_VALUE) return 0.0;
   return a[0];
  }

//==================================================================
//  STRUCTURE H4
//==================================================================
//  Un pivot a l'index i n'existe que si les n barres de chaque cote
//  sont DANS la fenetre [0 ; size-1]. "size" est donc la borne
//  temporelle : passer size = lastBar+1 restreint la confirmation
//  aux barres <= lastBar (C9).
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
//  C9 — L'impulsion est construite UNIQUEMENT avec les barres
//  d'index <= lastBar (barre de la cassure). Concretement :
//   - la confirmation du pivot d'ancrage utilise IsPivot*(..., lastBar+1)
//     donc n'exige/n'utilise que des barres <= lastBar ;
//   - l'extreme oppose est cherche sur [anchor ; lastBar].
//  Pour age = 0 (lastBar = size-1), strictement identique a v1.18.
//  lastUsedBar renvoie le plus grand index effectivement lu.
bool BuildImpulseLastLeg(const MqlRates &r[], const int size, const int dir,
                         const int lastBar, double &impHigh, double &impLow, int &lastUsedBar)
  {
   int n = InpSwingBars;
   int anchor = -1;
   int limit = MathMin(lastBar + 1, size);   // borne temporelle : t <= tBreak
   lastUsedBar = -1;

   for(int p = lastBar - 1; p >= n; p--)
     {
      if(dir > 0 && IsPivotLow (r, p, n, limit)) { anchor = p; break; }
      if(dir < 0 && IsPivotHigh(r, p, n, limit)) { anchor = p; break; }
     }
   if(anchor < 0) return false;

   if(dir > 0)
     {
      double lo = r[anchor].low;
      double hi = r[anchor].high;
      for(int i = anchor; i < limit; i++)
         if(r[i].high > hi) hi = r[i].high;
      impLow = lo; impHigh = hi;
     }
   else
     {
      double hi = r[anchor].high;
      double lo = r[anchor].low;
      for(int i = anchor; i < limit; i++)
         if(r[i].low < lo) lo = r[i].low;
      impHigh = hi; impLow = lo;
     }
   lastUsedBar = limit - 1;
   return (impHigh - impLow > 0.0);
  }

//------------------------------------------------------------------
bool BuildImpulseFullSeq(const MqlRates &r[], const int size, const int dir,
                         const int firstBar, const int lastBar,
                         double &impHigh, double &impLow, int &lastUsedBar)
  {
   int from  = MathMax(0, firstBar - InpImpulseLookback);
   int limit = MathMin(lastBar + 1, size);   // borne temporelle : t <= tBreak (C9)
   impHigh = 0.0; impLow = 0.0;
   lastUsedBar = -1;
   if(firstBar < 0 || firstBar >= limit) return false;

   if(dir > 0)
     {
      int idxHigh = firstBar;
      double hi = r[firstBar].high;
      for(int i = firstBar; i < limit; i++)
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
      for(int i = firstBar; i < limit; i++)
         if(r[i].low < lo) { lo = r[i].low; idxLow = i; }
      double hi = r[from].high;
      for(int i = from; i <= idxLow; i++)
         if(r[i].high > hi) hi = r[i].high;
      impHigh = hi; impLow = lo;
     }
   lastUsedBar = limit - 1;
   return (impHigh > impLow);
  }

//==================================================================
//  NOTE DE TENDANCE
//==================================================================
//  Tableaux statiques : CopyBuffer ecrit du plus ancien [0] au plus
//  recent [2]. fast[2] = barre 1 (derniere close), fast[0] = barre 3.
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
   g_setup.active            = false;
   g_setup.dir               = 0;
   g_setup.tBreak            = 0;
   g_setup.impHigh           = 0.0;
   g_setup.impLow            = 0.0;
   g_setup.counterOK         = false;
   g_setup.h1Count           = 0;
   g_setup.tLastH1           = 0;
   g_setup.h1Elapsed         = 0;
   g_setup.h4Elapsed         = 0;
   g_setup.score             = 0.0;
   g_setup.ordersPlaced      = false;
   g_setup.sessionRejCounted = false;
  }

double FibLevel(const int dir, const double impHigh, const double impLow, const double f)
  {
   double range = impHigh - impLow;
   if(dir > 0) return impHigh - f * range;
   return impLow + f * range;
  }

//==================================================================
//  FICHES DE POSITION (C4 / C12)
//==================================================================
int RecFind(const ulong id)
  {
   for(int i = g_recN - 1; i >= 0; i--)
      if(g_rec[i].id == id) return i;
   return -1;
  }

int RecNew(const ulong id, const int dir, const bool legB, const double score, const double riskPct,
           const double entryPlanned, const double slSent, const double rDistPlanned,
           const double impHigh, const double impLow, const bool recovered)
  {
   if(g_recN >= MAX_REC) return -1;
   int k = g_recN;
   g_rec[k].id           = id;
   g_rec[k].dir          = dir;
   g_rec[k].legB         = legB;
   g_rec[k].score        = score;
   g_rec[k].riskPct      = riskPct;
   g_rec[k].setupBreak   = g_setup.tBreak;
   g_rec[k].tOpen        = TimeCurrent();
   g_rec[k].entryPlanned = entryPlanned;
   g_rec[k].slSent       = slSent;
   g_rec[k].rDistPlanned = rDistPlanned;
   g_rec[k].volIn        = 0.0;
   g_rec[k].nIn          = 0;
   g_rec[k].nOut         = 0;
   int src = TICKSRC_NONE;
   g_rec[k].tickValue    = TickValueForLoss(src);
   g_rec[k].tickSize     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_rec[k].tickSource   = (recovered ? TICKSRC_RECOV : src);
   g_rec[k].mfe          = 0.0;
   g_rec[k].mae          = 0.0;
   g_rec[k].atrD1        = g_entryATRD1;
   g_rec[k].atrH4        = g_entryATRH4;
   g_rec[k].range        = g_entryRange;
   g_rec[k].kumo         = g_entryKumo;
   g_rec[k].spread       = g_entrySpread;
   g_rec[k].impHigh      = impHigh;
   g_rec[k].impLow       = impLow;
   g_recN++;
   s_positionsOpened++;
   return k;
  }

//==================================================================
//  SUIVI DES POSITIONS
//==================================================================
//  C6 — un ticket = une seule entree. Retourne false si deja suivi.
bool TrackAdd(const ulong ticket, const int dir, const double entryReal, const double entryPlanned,
              const double slSent, const double rDist, const bool legB, const double score,
              const double riskPct, const double impHigh, const double impLow, const bool recovered)
  {
   int dup = TrackFind(ticket);
   if(dup >= 0)
     {
      s_trackDuplicates++;
      Invariant(false, StringFormat("TrackAdd : ticket %I64u deja suivi (slot %d)", ticket, dup));
      return false;
     }
   if(g_trackN >= MAX_TRACK)
     {
      PrintFormat("TrackAdd : table pleine (%d), ticket %I64u non suivi.", MAX_TRACK, ticket);
      return false;
     }
   g_track[g_trackN].ticket  = ticket;
   g_track[g_trackN].dir     = dir;
   g_track[g_trackN].entry   = entryReal;
   g_track[g_trackN].rDist   = rDist;
   g_track[g_trackN].legB    = legB;
   g_track[g_trackN].beDone  = false;
   g_track[g_trackN].score   = score;
   g_track[g_trackN].riskPct = riskPct;
   g_track[g_trackN].tOpen   = TimeCurrent();
   g_track[g_trackN].impHigh = impHigh;
   g_track[g_trackN].impLow  = impLow;
   int ri = RecFind(ticket);
   if(ri < 0) ri = RecNew(ticket, dir, legB, score, riskPct, entryPlanned, slSent, rDist, impHigh, impLow, recovered);
   g_track[g_trackN].recIdx  = ri;
   g_trackN++;
   return true;
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
//  STOP LOSS — C1 / C2 / C11
//==================================================================
#define STOP_OK               0
#define STOP_REJECT_STOPS_CAP 1

//  C2 — SEMANTIQUE DE SLMODE_FURTHEST (confirmee, NON modifiee) :
//  "le plus eloigne de l'entree" entre le niveau Fibonacci InpSLFib et
//  l'extreme de l'impulsion. Pour un achat : MathMin(fibSL, impLow).
//  Or FibLevel(dir>0, f) = impHigh - f*range est >= impLow pour tout
//  f dans [0 ; 1]. Donc, avec InpSLFib <= 1, FURTHEST == EXTREME et le
//  parametre InpSLFib n'a d'effet qu'en mode SLMODE_FIB. Ce n'est pas
//  un bug de calcul : c'est la consequence de la definition. Pour que
//  le fib soit "plus loin" il faudrait InpSLFib > 1 (extension).
//  Comportement conserve pour ne pas changer la strategie.
//
//  Ordre deterministe : SL structurel -> tampon -> PLANCHER -> PLAFOND
//  -> contrainte courtier. Si la contrainte courtier exige une
//  distance > plafond, le trade est REFUSE (C1) : on ne sort jamais
//  de la bande [plancher ; plafond] pour satisfaire STOPS_LEVEL.
int ComputeStop(const int dir, const double entryPrice, const double impHigh, const double impLow,
                const double atrD1, const double minStop,
                double &sl, double &dist, double &structDist, double &floorD, double &capD,
                bool &clampedFloor, bool &clampedCap, bool &clampedStops)
  {
   clampedFloor = false; clampedCap = false; clampedStops = false;

   double fibSL = FibLevel(dir, impHigh, impLow, InpSLFib);
   double extSL = (dir > 0 ? impLow : impHigh);
   double buf   = InpSLBufferATR * atrD1;

   if(InpSLMode == SLMODE_FIB)          sl = fibSL;
   else if(InpSLMode == SLMODE_EXTREME) sl = extSL;
   else                                 sl = (dir > 0 ? MathMin(fibSL, extSL) : MathMax(fibSL, extSL));

   sl = (dir > 0 ? sl - buf : sl + buf);

   structDist = MathAbs(entryPrice - sl);
   floorD     = InpSLFloorATR * atrD1;
   capD       = InpSLCapATR   * atrD1;
   dist       = structDist;

   if(dist < floorD) { dist = floorD; clampedFloor = true; }
   if(dist > capD)   { dist = capD;   clampedCap   = true; }

   // --- contrainte courtier, SANS sortir de la bande ---------------
   if(minStop > 0.0 && dist < minStop)
     {
      // v1.18 elargissait a 1.5 x minStop sans regarder le plafond.
      // On garde la marge de 1.5 quand elle tient dans le plafond,
      // sinon on se colle au plafond ; si meme le plafond est sous
      // minStop, il n'existe aucune distance valide : refus.
      double need = MathMin(minStop * 1.5, capD);
      if(need < minStop) return STOP_REJECT_STOPS_CAP;
      dist = need;
      clampedStops = true;
     }

   sl = (dir > 0 ? entryPrice - dist : entryPrice + dist);
   return STOP_OK;
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
   double slSent = NP(sl);

   // --- jambe A --------------------------------------------------
   if(volA >= vmin)
     {
      string cA = BuildComment(false, rDist, score);
      bool ok;
      if(market)
         ok = (dir > 0) ? trade.Buy (volA, _Symbol, 0.0, slSent, NP(tp1), cA)
                        : trade.Sell(volA, _Symbol, 0.0, slSent, NP(tp1), cA);
      else
         ok = (dir > 0) ? trade.BuyLimit (volA, NP(entryPrice), _Symbol, slSent, NP(tp1), tt, exp, cA)
                        : trade.SellLimit(volA, NP(entryPrice), _Symbol, slSent, NP(tp1), tt, exp, cA);
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
         s_ordersPlaced++;
         if(market)
           {
            ulong tk = trade.ResultDeal(), pos = 0;
            if(HistoryDealSelect(tk)) pos = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
            if(pos > 0 && TrackFind(pos) < 0)
               TrackAdd(pos, dir, trade.ResultPrice(), entryPrice, slSent, rDist, false, score, riskPct, impHigh, impLow, false);
           }
        }
     }

   // --- jambe B --------------------------------------------------
   if(volB >= vmin)
     {
      string cB = BuildComment(true, rDist, score);
      bool ok;
      if(market)
         ok = (dir > 0) ? trade.Buy (volB, _Symbol, 0.0, slSent, (tp2 > 0 ? NP(tp2) : 0.0), cB)
                        : trade.Sell(volB, _Symbol, 0.0, slSent, (tp2 > 0 ? NP(tp2) : 0.0), cB);
      else
         ok = (dir > 0) ? trade.BuyLimit (volB, NP(entryPrice), _Symbol, slSent, (tp2 > 0 ? NP(tp2) : 0.0), tt, exp, cB)
                        : trade.SellLimit(volB, NP(entryPrice), _Symbol, slSent, (tp2 > 0 ? NP(tp2) : 0.0), tt, exp, cB);
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
         s_ordersPlaced++;
         if(market)
           {
            ulong tk = trade.ResultDeal(), pos = 0;
            if(HistoryDealSelect(tk)) pos = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
            if(pos > 0 && TrackFind(pos) < 0)
               TrackAdd(pos, dir, trade.ResultPrice(), entryPrice, slSent, rDist, true, score, riskPct, impHigh, impLow, false);
           }
        }
     }

   if(anyOK)
     {
      s_orderSets++;
      if(market) s_market++; else s_limit++;
      double atr = g_entryATRD1;
      Log(StringFormat("ENTREE %s %s | %s local | prix %.*f | SL %.*f | R %.2f $ = %.2f%% du prix = %.2f x ATR D1 | note %.0f | risque %.2f%% | vol %.2f+%.2f",
                       (dir > 0 ? "LONG" : "SHORT"), (market ? "marche" : "limite"),
                       BlockName(TimeCurrent()), _Digits, entryPrice, _Digits, sl,
                       rDist, 100.0 * rDist / entryPrice, (atr > 0 ? rDist / atr : 0.0),
                       score, riskPct, volA, volB));
      Log(DSTDiag(TimeCurrent()));
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

   // --- session, en heure LOCALE europeenne (C15 : 2 compteurs) ---
   if(!InSessionLocal(TimeCurrent()))
     {
      s_entryAttemptRejectedSession++;
      if(!g_setup.sessionRejCounted) { g_setup.sessionRejCounted = true; s_setupRejectedSession++; }
      if(InpSessionMode == SESS_HARD)
        {
         Log(StringFormat("Setup rejete : hors session (%s local).",
                          TimeToString(ServerToLocalEU(TimeCurrent()), TIME_MINUTES)));
         Log(DSTDiag(TimeCurrent()));
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

   int stopsLvl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStop = stopsLvl * Pt();

   // --- C11 : conversion limite -> marche AVANT le calcul du SL ---
   //  Meme condition qu'en v1.18 (independante du SL). Le SL est
   //  ensuite calcule sur le prix d'entree reellement envoye.
   if(!market && minStop > 0.0 && MathAbs(price - entryPrice) < minStop)
     {
      market = true; entryPrice = price;
      Log("Limite trop proche du marche (stops level) : ordre marche, SL recalcule sur le prix reel.");
     }

   // --- stop loss : structurel -> plancher -> plafond -> courtier --
   double sl = 0.0, dist = 0.0, structDist = 0.0, floorD = 0.0, capD = 0.0;
   bool cF = false, cC = false, cS = false;
   int rc = ComputeStop(dir, entryPrice, impHigh, impLow, atrD1, minStop,
                        sl, dist, structDist, floorD, capD, cF, cC, cS);
   if(cF) s_clampFloor++;
   if(cC) s_clampCap++;
   if(cS) s_clampStops++;
   if(rc == STOP_REJECT_STOPS_CAP)
     {
      s_rejStopsVsCap++;
      Log(StringFormat("REJECT_STOPS_VS_CAP : stops level %.2f $ (%d pts) > plafond %.2f $ (%.2f x ATR D1 %.2f). Trade refuse, setup conserve.",
                       minStop, stopsLvl, capD, InpSLCapATR, atrD1));
      return;   // setup conserve : si le stops level redescend, nouvelle tentative
     }

   // --- C19 : invariants du stop ----------------------------------
   Invariant((dir > 0 && sl < entryPrice) || (dir < 0 && sl > entryPrice),
             StringFormat("SL %.*f du mauvais cote de l'entree %.*f (dir %d)", _Digits, sl, _Digits, entryPrice, dir));
   Invariant(dist >= floorD - 1e-9,
             StringFormat("SL %.2f $ < plancher %.2f $", dist, floorD));
   Invariant(dist <= capD + 1e-9,
             StringFormat("SL %.2f $ > plafond %.2f $", dist, capD));
   Invariant(minStop <= 0.0 || dist >= minStop - 1e-9,
             StringFormat("SL %.2f $ < stops level %.2f $", dist, minStop));

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
      PrintFormat("  Stops level ....... %d pts = %.2f $", stopsLvl, minStop);
      PrintFormat("  Spread au moment de l'entree : %.0f points = %.2f $",
                  g_entrySpread, g_entrySpread * Pt());
      PrintFormat("  Slippage tolere ... %d pts = %.2f $ = %.3f x ATR D1 (C17 : en POINTS, non invariant d'echelle)",
                  InpSlippage, InpSlippage * Pt(), InpSlippage * Pt() / atrD1);
      int tsrc = TICKSRC_NONE;
      double tvl = TickValueForLoss(tsrc);
      PrintFormat("  Tick size %.5f | tick value (perte) %.5f [source %s] | perte par lot au SL %.2f",
                  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), tvl,
                  (tsrc == TICKSRC_LOSS ? "TICK_VALUE_LOSS" : (tsrc == TICKSRC_VALUE ? "TICK_VALUE (fallback)" : "AUCUNE")),
                  LossPerLot(dist));
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

   // C19 : r[size-1] est la derniere barre CLOSE, jamais la barre 0.
   datetime t0 = iTime(_Symbol, PERIOD_H4, 0);
   Invariant(r[size-1].time < t0,
             StringFormat("H4 : r[size-1] (%s) n'est pas anterieure a la barre 0 (%s)",
                          TimeToString(r[size-1].time), TimeToString(t0)));

   // C18 : une ligne de diagnostic DST par mois (journal detaille)
   MqlDateTime dnow;
   TimeToStruct(TimeCurrent(), dnow);
   if(dnow.mon != g_lastDiagMonth) { g_lastDiagMonth = dnow.mon; Log(DSTDiag(TimeCurrent())); }

   if(g_setup.active)
     {
      g_setup.h4Elapsed++;
      if(g_setup.h4Elapsed > InpSetupExpiryBarsH4 && !g_setup.ordersPlaced)
        { s_setupExpired++; Log("Setup perime (H4)."); ResetSetup(); }
      else if(!g_setup.ordersPlaced)
        {
         // C10 — invalidation structurelle sur la CLOTURE de la
         // derniere H4 (close < impLow / close > impHigh), pas sur la
         // meche. Regle strategique volontairement NON modifiee.
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

   // --- C9 : impulsion figee aux barres <= tBreak -----------------
   double impHigh, impLow;
   int lastUsed = -1;
   bool ok;
   if(InpImpulseMode == IMP_LAST_LEG)
      ok = BuildImpulseLastLeg(r, size, dir, lastBar, impHigh, impLow, lastUsed);
   else
      ok = BuildImpulseFullSeq(r, size, dir, firstBar, lastBar, impHigh, impLow, lastUsed);
   if(!ok) return;
   Invariant(lastUsed >= 0 && lastUsed <= lastBar,
             StringFormat("impulsion : derniere barre utilisee %d > barre de cassure %d", lastUsed, lastBar));
   Invariant(lastUsed < 0 || r[lastUsed].time <= tBreak,
             StringFormat("impulsion : barre %s posterieure a tBreak %s",
                          TimeToString(r[MathMax(lastUsed, 0)].time), TimeToString(tBreak)));

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

   // --- filtre Ichimoku H4 (C8 : fail-closed) ---------------------
   int kumo = KumoState();
   g_entryKumo = (double)kumo;
   if(InpKumoMode != KUMO_OFF)
     {
      if(kumo == 99)
        {
         // Donnee absente : le setup n'est PAS arme. La cassure n'est
         // pas consommee : re-evaluation a la H4 suivante (age + 1)
         // tant que age <= InpSetupExpiryBarsH4.
         s_rejIchimokuData++;
         Log(StringFormat("Setup NON ARME : donnees Ichimoku indisponibles (fail-closed), cassure %s, age %d.",
                          TimeToString(tBreak), age));
         return;
        }
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
   Invariant(InpKumoMode == KUMO_OFF || kumo != 99, "setup arme avec des donnees Ichimoku invalides");

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

   // --- C7 : sans filtre contre-tendance, eligible tout de suite ---
   //  v1.18 attendait la H4 SUIVANTE pour poser counterOK meme quand
   //  InpUseCounterCandle = false (une H4 de retard sans raison).
   //  Avec InpUseCounterCandle = true (defaut) : rien ne change.
   if(!InpUseCounterCandle)
     {
      s_counterOK++;
      g_setup.counterOK = true;
      g_setup.h1Count   = 0;
      g_setup.h1Elapsed = 0;
      Log("Filtre contre-tendance inactif : confirmation H1 eligible des maintenant (C7).");
     }

   Log(StringFormat("SETUP ARME %s | %d cassures | cassure %s (age %d H4) | impulsion %.*f - %.*f (%.2f%%) figee a la barre %d <= %d | note %.0f",
                    (dir > 0 ? "LONG" : "SHORT"), cnt, TimeToString(tBreak), age,
                    _Digits, impLow, _Digits, impHigh,
                    (px > 0 ? 100.0 * (impHigh - impLow) / px : 0.0), lastUsed, lastBar, score));
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

   // C19 : derniere barre H1 CLOSE, jamais la barre 0.
   Invariant(last.time < iTime(_Symbol, PERIOD_H1, 0),
             StringFormat("H1 : barre de confirmation %s n'est pas anterieure a la barre 0", TimeToString(last.time)));

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
         // Position retrouvee sans suivi (redemarrage, evenement
         // manque) : fiche marquee "recuperee" (valeurs courantes).
         int dirp = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
         double po = PositionGetDouble(POSITION_PRICE_OPEN);
         TrackAdd(tk, dirp, po, po, PositionGetDouble(POSITION_SL), rDist, legB,
                  g_setup.score, 0.0, g_setup.impHigh, g_setup.impLow, true);
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

      if(idx >= 0 && g_track[idx].recIdx >= 0)
        {
         int ri = g_track[idx].recIdx;
         if(profitR > g_rec[ri].mfe) g_rec[ri].mfe = profitR;
         if(profitR < g_rec[ri].mae) g_rec[ri].mae = profitR;
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
      // C16 : comportement INCHANGE ; seuls des compteurs sont ajoutes.
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
         if(ok)
           {
            s_positionModifyCalls++;
            if(trade.PositionModify(tk, NP(newSL), curTP)) s_positionModifySuccess++;
            else
              {
               s_positionModifyFailed++;
               Log(StringFormat("PositionModify echoue (#%I64u) : %s", tk, trade.ResultRetcodeDescription()));
              }
           }
        }
     }
  }

//==================================================================
//  CSV + BILAN — C4 / C12 / C13 / C14
//==================================================================
//  Une ligne = une POSITION (DEAL_POSITION_ID), jamais un deal.
//  Volume, prix moyen, PnL, swap, commission : agreges sur TOUS les
//  deals IN/OUT de la position (fills partiels, cloture partielle).
//  Risque monetaire : (|entree reelle - SL envoye| / tickSize) *
//  tickValue(perte) * volume execute, avec tickSize / tickValue
//  MEMORISES a l'entree (fiche PosRec). Sans fiche : valeurs
//  courantes du symbole, ligne marquee FALLBACK et comptee.
struct PosAgg
  {
   ulong    id;
   int      dir;
   bool     legB;
   bool     hasComment;
   double   score;
   double   rDistPlanned;
   double   volIn;
   double   volOut;
   double   entrySum;     // somme prix*vol des IN
   double   exitSum;      // somme prix*vol des OUT
   double   profit;
   double   swap;
   double   comm;
   datetime tIn;
   datetime tOut;
   int      nIn;
   int      nOut;
   bool     tpHit;
   bool     slHit;
   int      recIdx;
   datetime setupKey;
  };

int AggFind(const PosAgg &agg[], const int n, const ulong id)
  {
   for(int i = 0; i < n; i++)
      if(agg[i].id == id) return i;
   return -1;
  }

void WriteCSVFromHistory()
  {
   if(!HistorySelect(0, TimeCurrent() + 86400))
     { Print("Bilan : historique indisponible."); return; }

   int total = HistoryDealsTotal();
   if(total <= 0) { Print("Bilan : aucune transaction."); return; }

   PosAgg agg[];
   ArrayResize(agg, total);
   int nAgg = 0;

   // --- 1. agregation par position --------------------------------
   for(int i = 0; i < total; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      long dtype = HistoryDealGetInteger(tk, DEAL_TYPE);
      if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) continue;   // pas de balance/credit
      ulong pid = (ulong)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
      if(pid == 0) continue;

      int k = AggFind(agg, nAgg, pid);
      if(k < 0)
        {
         k = nAgg++;
         ZeroMemory(agg[k]);
         agg[k].id     = pid;
         agg[k].recIdx = RecFind(pid);
         agg[k].tIn    = 0;
         agg[k].tOut   = 0;
        }

      double vol   = HistoryDealGetDouble(tk, DEAL_VOLUME);
      double price = HistoryDealGetDouble(tk, DEAL_PRICE);
      datetime dt  = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      agg[k].comm  += HistoryDealGetDouble(tk, DEAL_COMMISSION);
      agg[k].swap  += HistoryDealGetDouble(tk, DEAL_SWAP);
      agg[k].profit+= HistoryDealGetDouble(tk, DEAL_PROFIT);

      if(entry == DEAL_ENTRY_IN)
        {
         agg[k].nIn++;
         agg[k].volIn    += vol;
         agg[k].entrySum += price * vol;
         if(agg[k].tIn == 0 || dt < agg[k].tIn) agg[k].tIn = dt;
         if(agg[k].dir == 0) agg[k].dir = (dtype == DEAL_TYPE_BUY ? 1 : -1);
         if(!agg[k].hasComment)
           {
            bool lb; double rd, sc;
            if(ParseComment(HistoryDealGetString(tk, DEAL_COMMENT), lb, rd, sc))
              { agg[k].hasComment = true; agg[k].legB = lb; agg[k].rDistPlanned = rd; agg[k].score = sc; }
           }
        }
      else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
        {
         agg[k].nOut++;
         agg[k].volOut  += vol;
         agg[k].exitSum += price * vol;
         if(dt > agg[k].tOut) agg[k].tOut = dt;
         long reason = HistoryDealGetInteger(tk, DEAL_REASON);
         if(reason == DEAL_REASON_TP) agg[k].tpHit = true;
         if(reason == DEAL_REASON_SL) agg[k].slHit = true;
        }
     }

   // --- 2. completer depuis la fiche (jambe, dir, setup) ----------
   for(int k = 0; k < nAgg; k++)
     {
      int ri = agg[k].recIdx;
      if(ri >= 0)
        {
         if(!agg[k].hasComment) { agg[k].legB = g_rec[ri].legB; agg[k].rDistPlanned = g_rec[ri].rDistPlanned; agg[k].score = g_rec[ri].score; }
         if(agg[k].dir == 0) agg[k].dir = g_rec[ri].dir;
         agg[k].setupKey = (g_rec[ri].setupBreak > 0 ? g_rec[ri].setupBreak : agg[k].tIn);
        }
      else
         agg[k].setupKey = (datetime)(((long)agg[k].tIn / 60) * 60);   // jambes envoyees a la meme minute
     }

   // --- 3. CSV -----------------------------------------------------
   int h = INVALID_HANDLE;
   if(InpWriteCSV)
     {
      h = FileOpen(InpCSVName, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');
      if(h == INVALID_HANDLE)
         Print("CSV : ouverture impossible (", GetLastError(), ")");
      else
         FileWrite(h, "pos_id", "setup_id", "closed", "time_in", "time_out", "leg", "dir",
                   "entry_real", "sl_real", "exit_avg", "vol_in", "vol_out", "n_in", "n_out",
                   "r_planned_pts", "r_real_dollars", "sl_pct", "sl_atr_d1",
                   "tick_size", "tick_value_loss", "tick_src", "risk_ccy",
                   "R_brut", "R_net", "profit", "swap", "commission", "reason",
                   "score", "duration_h", "atr_d1", "atr_h4", "range_pts", "range_atr", "kumo",
                   "MFE_R", "MAE_R", "year", "hour_local", "block", "spread_pts", "fallback");
     }

   // --- 4. bilan ---------------------------------------------------
   int    nClosed = 0, nOpen = 0, nA = 0, nB = 0, nMFE2 = 0, nTP1 = 0, nTP2 = 0, nSL = 0;
   double pA = 0, pB = 0, swA = 0, swB = 0, cmA = 0, cmB = 0;
   double rbA = 0, rbB = 0, rnA = 0, rnB = 0, riskA = 0, riskB = 0;
   double sumHold = 0, sumSwapR = 0, sumCommR = 0;
   long   nJour = 0, nSoir = 0, nNuit = 0;
   double rbJour = 0, rbSoir = 0, rbNuit = 0, rnJour = 0, rnSoir = 0, rnNuit = 0;
   int    written = 0;

   // groupes par setup (R du setup = PnL A+B / risque A+B)
   datetime setupKeys[];  double setupPnl[]; double setupRisk[]; int nSetups = 0;
   ArrayResize(setupKeys, nAgg); ArrayResize(setupPnl, nAgg); ArrayResize(setupRisk, nAgg);

   double curTS = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   int    curSrc = TICKSRC_NONE;
   double curTV = TickValueForLoss(curSrc);

   for(int k = 0; k < nAgg; k++)
     {
      if(agg[k].volIn <= 0.0) continue;
      bool closed   = (agg[k].volOut >= agg[k].volIn - 1e-9);
      double entryAvg = agg[k].entrySum / agg[k].volIn;
      double exitAvg  = (agg[k].volOut > 0.0 ? agg[k].exitSum / agg[k].volOut : 0.0);

      int ri = agg[k].recIdx;
      bool fallback = (ri < 0 || g_rec[ri].tickSource == TICKSRC_NONE || g_rec[ri].tickSource == TICKSRC_RECOV);
      double ts  = (ri >= 0 && g_rec[ri].tickSize  > 0.0 ? g_rec[ri].tickSize  : curTS);
      double tv  = (ri >= 0 && g_rec[ri].tickValue > 0.0 ? g_rec[ri].tickValue : curTV);
      int    src = (ri >= 0 ? g_rec[ri].tickSource : TICKSRC_NONE);
      double slReal = (ri >= 0 ? g_rec[ri].slSent : 0.0);
      double rReal  = (slReal > 0.0 ? MathAbs(entryAvg - slReal) : agg[k].rDistPlanned);
      if(rReal <= 0.0) rReal = agg[k].rDistPlanned;
      if(fallback) s_csvFallback++;

      double riskCcy = LossPerLotWith(rReal, ts, tv) * agg[k].volIn;   // 1 R en devise, memorise
      double pnlNet  = agg[k].profit + agg[k].swap + agg[k].comm;
      double Rbrut   = (rReal > 0.0 && closed ? agg[k].dir * (exitAvg - entryAvg) / rReal : 0.0);
      double Rnet    = (riskCcy > 0.0 && closed ? pnlNet / riskCcy : 0.0);
      double swapR   = (riskCcy > 0.0 ? agg[k].swap / riskCcy : 0.0);
      double commR   = (riskCcy > 0.0 ? agg[k].comm / riskCcy : 0.0);
      double slPct   = (entryAvg > 0.0 ? 100.0 * rReal / entryAvg : 0.0);
      double durH    = (closed && agg[k].tOut > 0 ? (double)(agg[k].tOut - agg[k].tIn) / 3600.0 : 0.0);

      double aD1 = (ri >= 0 ? g_rec[ri].atrD1  : 0.0);
      double aH4 = (ri >= 0 ? g_rec[ri].atrH4  : 0.0);
      double rng = (ri >= 0 ? g_rec[ri].range  : 0.0);
      double kum = (ri >= 0 ? g_rec[ri].kumo   : 99.0);
      double mfe = (ri >= 0 ? g_rec[ri].mfe    : 0.0);
      double mae = (ri >= 0 ? g_rec[ri].mae    : 0.0);
      double spd = (ri >= 0 ? g_rec[ri].spread : 0.0);
      double slAtr  = (aD1 > 0.0 ? rReal / aD1 : 0.0);
      double rngAtr = (aD1 > 0.0 ? rng   / aD1 : 0.0);

      MqlDateTime dl;
      TimeToStruct(ServerToLocalEU(agg[k].tIn), dl);
      double hLoc = (double)dl.hour + (double)dl.min / 60.0;
      string blk  = BlockName(agg[k].tIn);
      string reason = (agg[k].tpHit ? "TP" : (agg[k].slHit ? "SL" : (closed ? "OTHER" : "OPEN")));

      if(closed)
        {
         nClosed++;
         sumHold += durH; sumSwapR += swapR; sumCommR += commR;
         if(mfe >= 2.0) nMFE2++;
         if(agg[k].slHit) nSL++;
         if(agg[k].legB) { nB++; pB += agg[k].profit; swB += agg[k].swap; cmB += agg[k].comm; rbB += Rbrut; rnB += Rnet; riskB += riskCcy; if(agg[k].tpHit) nTP2++; }
         else            { nA++; pA += agg[k].profit; swA += agg[k].swap; cmA += agg[k].comm; rbA += Rbrut; rnA += Rnet; riskA += riskCcy; if(agg[k].tpHit) nTP1++; }
         if(blk == "JOUR")      { nJour++; rbJour += Rbrut; rnJour += Rnet; }
         else if(blk == "SOIR") { nSoir++; rbSoir += Rbrut; rnSoir += Rnet; }
         else                   { nNuit++; rbNuit += Rbrut; rnNuit += Rnet; }

         int sidx = -1;
         for(int s = 0; s < nSetups; s++) if(setupKeys[s] == agg[k].setupKey) { sidx = s; break; }
         if(sidx < 0) { sidx = nSetups++; setupKeys[sidx] = agg[k].setupKey; setupPnl[sidx] = 0.0; setupRisk[sidx] = 0.0; }
         setupPnl[sidx]  += pnlNet;
         setupRisk[sidx] += riskCcy;
        }
      else nOpen++;

      if(h != INVALID_HANDLE)
        {
         FileWrite(h,
                   IntegerToString((long)agg[k].id),
                   TimeToString(agg[k].setupKey, TIME_DATE | TIME_MINUTES),
                   (closed ? "1" : "0"),
                   TimeToString(agg[k].tIn, TIME_DATE | TIME_MINUTES),
                   (closed ? TimeToString(agg[k].tOut, TIME_DATE | TIME_MINUTES) : ""),
                   (agg[k].legB ? "B" : "A"),
                   (agg[k].dir > 0 ? "LONG" : "SHORT"),
                   DoubleToString(entryAvg, _Digits),
                   DoubleToString(slReal, _Digits),
                   DoubleToString(exitAvg, _Digits),
                   DoubleToString(agg[k].volIn, 2),
                   DoubleToString(agg[k].volOut, 2),
                   IntegerToString(agg[k].nIn),
                   IntegerToString(agg[k].nOut),
                   DoubleToString(agg[k].rDistPlanned / Pt(), 0),
                   DoubleToString(rReal, 2),
                   DoubleToString(slPct, 3),
                   DoubleToString(slAtr, 3),
                   DoubleToString(ts, 5),
                   DoubleToString(tv, 5),
                   IntegerToString(src),
                   DoubleToString(riskCcy, 2),
                   DoubleToString(Rbrut, 4),
                   DoubleToString(Rnet, 4),
                   DoubleToString(agg[k].profit, 2),
                   DoubleToString(agg[k].swap, 2),
                   DoubleToString(agg[k].comm, 2),
                   reason,
                   DoubleToString(agg[k].score, 0),
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
                   DoubleToString(spd, 0),
                   (fallback ? "1" : "0"));
         written++;
        }
     }

   if(h != INVALID_HANDLE)
     {
      FileClose(h);
      PrintFormat("CSV : %d positions ecrites dans le dossier COMMUN -> %s", written, InpCSVName);
      Print("Chemin : ...\\MetaQuotes\\Terminal\\Common\\Files\\", InpCSVName);
     }

   int nTot = nA + nB;
   PrintFormat("=== BILAN (positions FERMEES, jambes A + B) ===");
   PrintFormat("Setups armes ............... %I64d", s_armed);
   PrintFormat("Setups entres (jeux) ....... %I64d   | setups avec PnL %d", s_orderSets, nSetups);
   PrintFormat("Ordres acceptes ............ %I64d", s_ordersPlaced);
   PrintFormat("Positions ouvertes ......... %I64d   (agregees dans l'historique : %d, dont encore ouvertes %d)", s_positionsOpened, nAgg, nOpen);
   PrintFormat("Positions fermees .......... %d", nClosed);
   PrintFormat("Entry deals / exit deals ... %I64d / %I64d   | fills partiels %I64d", s_entryDeals, s_exitDeals, s_partialFills);
   PrintFormat("TP1 (jambe A) / TP2 (B) .... %d / %d   | SL touches %d", nTP1, nTP2, nSL);
   PrintFormat("Lignes sans risque memorise  %I64d (fallback, valeurs courantes du symbole)", s_csvFallback);
   if(nTot <= 0) { Print("Aucune position fermee : pas de bilan en R."); return; }

   PrintFormat("--- par jambe ---");
   PrintFormat("Jambe A : %4d pos | brut %+.2f | swap %+.2f | comm %+.2f | R brut %+.2f | R net %+.2f", nA, pA, swA, cmA, rbA, rnA);
   PrintFormat("Jambe B : %4d pos | brut %+.2f | swap %+.2f | comm %+.2f | R brut %+.2f | R net %+.2f", nB, pB, swB, cmB, rbB, rnB);
   PrintFormat("TOTAL   : %4d pos | brut %+.2f | swap %+.2f | comm %+.2f | R brut %+.2f | R net %+.2f",
               nTot, pA + pB, swA + swB, cmA + cmB, rbA + rbB, rnA + rnB);
   PrintFormat("Profit NET (devise) ........ %+.2f", pA + pB + swA + swB + cmA + cmB);
   PrintFormat("Valeur moyenne de 1 R ...... %.2f (devise du compte, memorisee a l'entree)", (riskA + riskB) / nTot);
   PrintFormat("Tenue moyenne .............. %.1f h", sumHold / nTot);
   PrintFormat("R BRUT (prix seul) ......... %+.2f R   (%+.3f R/position)", rbA + rbB, (rbA + rbB) / nTot);
   PrintFormat("  - swap ................... %+.2f R", sumSwapR);
   PrintFormat("  - commission ............. %+.2f R", sumCommR);
   PrintFormat("R NET ...................... %+.2f R   (%+.3f R/position)", rnA + rnB, (rnA + rnB) / nTot);

   double sumRsetup = 0.0;
   for(int s = 0; s < nSetups; s++) if(setupRisk[s] > 0.0) sumRsetup += setupPnl[s] / setupRisk[s];
   PrintFormat("R NET par SETUP (A+B) ...... %+.2f R   (%+.3f R/setup sur %d setups)", sumRsetup,
               (nSetups > 0 ? sumRsetup / nSetups : 0.0), nSetups);
   PrintFormat("P(MFE >= 2R) ............... %.1f %%   [marche aleatoire = 33.3 %%]",
               100.0 * (double)nMFE2 / (double)nTot);
   PrintFormat("  Sous 33.3 %%, l'ENTREE n'apporte pas d'information : le");
   PrintFormat("  resultat vient du suiveur et de la modulation du risque.");

   PrintFormat("=== VENTILATION PAR BLOC (heure locale EU, positions) ===");
   PrintFormat("JOUR 08:00-17:30 ... %I64d pos | brut %+.2f R | NET %+.2f R | %+.3f R/pos net",
               nJour, rbJour, rnJour, (nJour > 0 ? rnJour / (double)nJour : 0.0));
   PrintFormat("SOIR 17:30-23:30 ... %I64d pos | brut %+.2f R | NET %+.2f R | %+.3f R/pos net",
               nSoir, rbSoir, rnSoir, (nSoir > 0 ? rnSoir / (double)nSoir : 0.0));
   PrintFormat("NUIT 23:30-08:00 ... %I64d pos | brut %+.2f R | NET %+.2f R | %+.3f R/pos net",
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

   // --- C5 : hedging obligatoire. Deux jambes A/B sur un compte
   //     netting fusionnent en UNE position (meme POSITION_ID,
   //     dernier TP/commentaire) : suivi, TP1/TP2 et suiveur seraient
   //     faux sans que rien ne le signale. Refus explicite.
   long marginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("ERROR: EA requires HEDGING account mode");
      PrintFormat("  ACCOUNT_MARGIN_MODE = %d (%s). Les deux jambes A/B fusionneraient en netting.",
                  (int)marginMode,
                  (marginMode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING ? "RETAIL_NETTING" :
                   (marginMode == ACCOUNT_MARGIN_MODE_EXCHANGE ? "EXCHANGE" : "INCONNU")));
      Invariant(false, "compte non hedging accepte");
      return INIT_FAILED;
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
   g_recN   = 0;
   g_scalePrinted  = false;
   g_lastDiagMonth = -1;

   PrintFormat("=== CHOCH_XAU_EA v1.18.1 — STOPS A L'ECHELLE DE L'ATR + FIABILISATION TECHNIQUE ===");
   PrintFormat("Symbole %s | Point %.5f | Digits %d | contrat %.0f",
               _Symbol, _Point, _Digits, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
   PrintFormat("Courtier %s | devise %s | levier 1:%d | mode de marge HEDGING (verifie)",
               AccountInfoString(ACCOUNT_COMPANY), AccountInfoString(ACCOUNT_CURRENCY),
               (int)AccountInfoInteger(ACCOUNT_LEVERAGE));
   int tsrc = TICKSRC_NONE;
   double tvl = TickValueForLoss(tsrc);
   PrintFormat("Tick size %.5f | tick value perte %.5f (%s) | tick value %.5f | stops level %d pts | freeze level %d pts",
               SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), tvl,
               (tsrc == TICKSRC_LOSS ? "TICK_VALUE_LOSS" : (tsrc == TICKSRC_VALUE ? "TICK_VALUE fallback" : "AUCUNE")),
               SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
   PrintFormat("Impulsion : %s (figee aux barres <= cassure, C9)", (InpImpulseMode == IMP_LAST_LEG ? "DERNIERE JAMBE" : "SEQUENCE COMPLETE"));
   string trg = "LIMITE au fib";
   if(InpEntryTrigger == TRIG_MARKET_ZONE) trg = "MARCHE si en zone";
   if(InpEntryTrigger == TRIG_MARKET_ANY)  trg = "MARCHE, zone ignoree";
   PrintFormat("Declenchement : %s | cassures %d | fractale H4 %d",
               trg, InpBreaksRequired, InpSwingBars);
   PrintFormat("STOP : fib %.2f, mode %d, tampon %.2f x ATR | plancher %.2f x ATR | plafond %.2f x ATR",
               InpSLFib, (int)InpSLMode, InpSLBufferATR, InpSLFloorATR, InpSLCapATR);
   if(InpSLMode == SLMODE_FURTHEST && InpSLFib <= 1.0)
      PrintFormat("  NOTE C2 : en mode FURTHEST avec fib <= 1, le SL structurel est l'EXTREME de l'impulsion (InpSLFib sans effet).");
   PrintFormat("  Aucun parametre de stop en points ni en %% du prix : le reglage");
   PrintFormat("  est transposable d'un courtier a l'autre quel que soit _Point.");
   PrintFormat("  Stops level > plafond => trade REFUSE (REJECT_STOPS_VS_CAP), jamais de SL hors bande.");
   PrintFormat("Slippage %d pts = %.2f $ (C17 : en POINTS ; sur un XAUUSD 3 digits le meme reglage vaudrait %.3f $)",
               InpSlippage, InpSlippage * Pt(), InpSlippage * Pt() / 10.0);
   PrintFormat("Risque %.2f-%.2f%% | TP1 %.2fR | suiveur %.2fR/%.2fR | pas %.2fR | BE %s",
               InpRiskTotalMin, InpRiskTotalMax, InpTP1_R, InpTrailStartR, InpTrailDistR,
               InpTrailStepR, (InpBEafterTP1 ? "OUI" : "NON"));
   if(InpTrailStepR <= 0.0)
      PrintFormat("  Pas du suiveur a 0 : un modify par amelioration, meme minuscule (compte en fin de test, C16).");
   PrintFormat("Sens autorises : achats %s / ventes %s",
               (InpTradeLong ? "OUI" : "NON"), (InpTradeShort ? "OUI" : "NON"));
   string km = "INACTIF";
   if(InpKumoMode == KUMO_PRO_IN) km = "PRO-TENDANCE + INTERIEUR DU NUAGE";
   if(InpKumoMode == KUMO_STRICT) km = "STRICT";
   PrintFormat("Filtre Ichimoku H4 : %s  (%d/%d/%d) | donnees absentes => setup non arme (C8)", km, InpTenkan, InpKijun, InpSenkou);
   PrintFormat("Bougie contre-tendance : %s%s", (InpUseCounterCandle ? "EXIGEE" : "NON EXIGEE"),
               (InpUseCounterCandle ? "" : " (C7 : confirmation H1 eligible des l'armement)"));
   PrintFormat("Invariants de diagnostic (C19) : %s", (InpDiagInvariants ? "ACTIFS" : "inactifs"));

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
   Print(DSTDiag(TimeCurrent()));
   MqlDateTime dn;
   TimeToStruct(TimeCurrent(), dn);
   PrintDSTTransitions(dn.year);

   return INIT_SUCCEEDED;
  }

//------------------------------------------------------------------
void OnDeinit(const int reason)
  {
   PrintFormat("=== ENTONNOIR (setups) ===");
   PrintFormat("Setups armes .............. %I64d", s_armed);
   PrintFormat("  rejetes (note) .......... %I64d", s_rejScore);
   PrintFormat("  rejetes (amplitude) ..... %I64d", s_rejRange);
   PrintFormat("  rejetes par Ichimoku .... %I64d", s_rejKumo);
   PrintFormat("  NON armes : Ichimoku absent %I64d  (fail-closed, C8)", s_rejIchimokuData);
   PrintFormat("  rejetes par le sens ..... %I64d", s_rejDir);
   PrintFormat("Bougie contre-tendance OK . %I64d  (echecs %I64d)", s_counterOK, s_counterKO);
   PrintFormat("Confirmations H1 .......... %I64d  (echecs %I64d)", s_confirm, s_confirmKO);
   PrintFormat("Confirmations hors zone ... %I64d", s_outOfZone);
   PrintFormat("Setups rejetes SESSION .... %I64d  (tentatives H1 hors session %I64d)", s_setupRejectedSession, s_entryAttemptRejectedSession);
   PrintFormat("Refuses : ATR D1 absent ... %I64d", s_noATR);
   PrintFormat("Refuses : REJECT_STOPS_VS_CAP %I64d  (stops level > plafond ATR, C1)", s_rejStopsVsCap);
   PrintFormat("Setups perimes / invalides  %I64d / %I64d", s_setupExpired, s_invalid);

   PrintFormat("=== EXECUTION (C3 : deals != positions != setups) ===");
   PrintFormat("Jeux d'ordres poses ....... %I64d  (marche %I64d / limite %I64d)", s_orderSets, s_market, s_limit);
   PrintFormat("Ordres acceptes ........... %I64d  (echecs d'envoi %I64d, dont marche ferme %I64d)", s_ordersPlaced, s_sendFail, s_marketClosed);
   PrintFormat("  volume nul .............. %I64d  | volume plafonne (marge) %I64d", s_volZero, s_capped);
   PrintFormat("Positions ouvertes ........ %I64d", s_positionsOpened);
   PrintFormat("Positions fermees ......... %I64d", s_positionsClosed);
   PrintFormat("Entry deals ............... %I64d  (fills partiels %I64d)", s_entryDeals, s_partialFills);
   PrintFormat("Exit deals ................ %I64d  (TP1 %I64d / TP2 %I64d / SL %I64d)", s_exitDeals, s_tp1Hits, s_tp2Hits, s_slHits);
   PrintFormat("Doublons de suivi refuses . %I64d", s_trackDuplicates);
   PrintFormat("PositionModify (suiveur) .. %I64d appels | %I64d succes | %I64d echecs", s_positionModifyCalls, s_positionModifySuccess, s_positionModifyFailed);
   PrintFormat("Invariants violes ......... %I64d", s_invariantFail);

   PrintFormat("=== ECRETAGE DU STOP  (LE CONTROLE QUI MANQUAIT) ===");
   double np = (double)MathMax(s_orderSets, 1);
   PrintFormat("SL ramene au PLANCHER ..... %I64d  (%.1f %% des jeux d'ordres)", s_clampFloor, 100.0 * s_clampFloor / np);
   PrintFormat("SL ramene au PLAFOND ...... %I64d  (%.1f %% des jeux d'ordres)", s_clampCap,   100.0 * s_clampCap   / np);
   PrintFormat("SL elargi (stops level) ... %I64d  (dans la bande) | refus REJECT_STOPS_VS_CAP %I64d", s_clampStops, s_rejStopsVsCap);
   PrintFormat("  (compteurs incrementes par TENTATIVE d'entree, pas par position)");
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
//  C3 / C6 / C12 — chaque deal est compte UNE fois ; une position
//  n'est suivie qu'une fois ; les deals IN supplementaires sur une
//  position deja connue sont des fills partiels.
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;

   long  entryType = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong posID     = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   double dealVol  = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double dealPx   = HistoryDealGetDouble(trans.deal, DEAL_PRICE);

   if(entryType == DEAL_ENTRY_IN)
     {
      s_entryDeals++;

      int ri = RecFind(posID);
      bool known = (ri >= 0 || TrackFind(posID) >= 0);
      bool partial = false;
      if(known && ri >= 0 && g_rec[ri].nIn >= 1) partial = true;      // 2e deal IN sur la meme position
      if(!partial && trans.order > 0 && HistoryOrderSelect(trans.order))
        {
         double vInit = HistoryOrderGetDouble(trans.order, ORDER_VOLUME_INITIAL);
         if(vInit > 0.0 && dealVol < vInit - 1e-9) partial = true;    // 1er deal ne remplit pas l'ordre
        }
      if(partial)
        {
         s_partialFills++;
         Log(StringFormat("Fill partiel : position %I64u, deal %.2f lot(s).", posID, dealVol));
        }

      if(TrackFind(posID) < 0)
        {
         string cmt = HistoryDealGetString(trans.deal, DEAL_COMMENT);
         bool legB; double rDist, sc;
         if(ParseComment(cmt, legB, rDist, sc))
           {
            long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
            int dir = (dtype == DEAL_TYPE_BUY ? 1 : -1);
            // SL reellement en place : position (prioritaire), sinon
            // ordre d'origine, sinon SL planifie depuis le commentaire.
            double slReal = 0.0;
            if(PositionSelectByTicket(posID)) slReal = PositionGetDouble(POSITION_SL);
            if(slReal <= 0.0 && trans.order > 0 && HistoryOrderSelect(trans.order))
               slReal = HistoryOrderGetDouble(trans.order, ORDER_SL);
            if(slReal <= 0.0) slReal = (dir > 0 ? dealPx - rDist : dealPx + rDist);
            double planned = dealPx;
            if(trans.order > 0 && HistoryOrderSelect(trans.order))
              {
               double op = HistoryOrderGetDouble(trans.order, ORDER_PRICE_OPEN);
               if(op > 0.0) planned = op;
              }
            TrackAdd(posID, dir, dealPx, planned, slReal, rDist, legB,
                     g_setup.score, RiskFromScore(g_setup.score), g_setup.impHigh, g_setup.impLow, false);
            ri = RecFind(posID);
           }
         else
            Log(StringFormat("Deal IN %I64u : commentaire '%s' illisible, position %I64u non suivie (courtier a reecrit le commentaire ?).",
                             trans.deal, cmt, posID));
        }

      if(ri >= 0)
        {
         g_rec[ri].nIn++;
         g_rec[ri].volIn += dealVol;
        }
      return;
     }

   if(entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT || entryType == DEAL_ENTRY_OUT_BY)
     {
      s_exitDeals++;
      int ri = RecFind(posID);
      long reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
      bool legB = (ri >= 0 ? g_rec[ri].legB : true);
      if(reason == DEAL_REASON_TP) { if(legB) s_tp2Hits++; else s_tp1Hits++; }
      if(reason == DEAL_REASON_SL) s_slHits++;
      if(ri >= 0) g_rec[ri].nOut++;
      if(!PositionSelectByTicket(posID)) s_positionsClosed++;   // volume integralement sorti
      return;
     }
  }
//+------------------------------------------------------------------+
