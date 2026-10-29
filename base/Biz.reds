module CorpoBiz

// ---------------------------------------------------------------------------
// CorpoBiz Framework -- data types.
//
// A business is described entirely by a BizDef (pure data, built once by a
// business-specific "catalog" file like SeventhHell.reds) plus a bizId used
// to namespace its persisted state. The generic engine (CorpoBiz.reds,
// CorpoBizState.reds, CorpoBizPrereqs.reds, StaffSpawner.reds,
// HostileCleanup.reds, TerminalUI.reds) never hardcodes anything about a
// specific business -- it only ever operates on BizDef/BizRoleDef values
// handed to it. Adding a second business later means writing one more
// catalog file and adding it to Registry.reds; nothing else in the engine
// changes.
//
// array<Struct> has no callable methods in this redscript build (.PushBack/
// .Size fail with "has no members", confirmed via isolated repro) -- every
// array<BizPrereq>/array<BizRoleDef>-shaped thing here is only ever built as
// a literal and consumed with a for-in loop, which is a different, working
// compiler path.

public enum BizPrereqKind {
  Quest = 0,
  Level = 1,
  Stat = 2
}

// A single purchase gate. Only the field(s) matching `kind` are meaningful.
public struct BizPrereq {
  let kind: BizPrereqKind;

  // Quest: a Facts-system flag that must be >= 1. Works equally well for a
  // real vanilla quest-completion fact or a self-asserted "pretend this is
  // done" flag -- see SeventhHell.reds for why 7th Hell uses the latter.
  let questFact: CName;

  // Level: player character level.
  let requiredLevel: Int32;

  // Stat: a player attribute, e.g. gamedataStatType.Strength for the "Body"
  // attribute shown in the UI (the game's internal stat name for Body is
  // Strength -- a historical naming mismatch, not a mistake here).
  let stat: gamedataStatType;
  let requiredStatValue: Float;
}

// One hireable, spawnable staff position.
public struct BizRoleDef {
  let id: CName;
  let templatePath: ResRef;
  let position: Vector4;
  let orientation: Quaternion;
  let hireCost: Int32;
  let revenuePerDay: Int32;
}

public struct BizDef {
  let id: CName;
  let displayName: String;
  let purchasePrice: Int32;
  let prereqs: array<BizPrereq>;
  let terminalPosition: Vector4;

  // Full role definitions, embedded directly rather than split into an id
  // list plus an external lookup function -- that keeps staff spawning and
  // revenue accrual in the generic engine free of any per-business code.
  let roles: array<BizRoleDef>;

  // Resources this business consumes per production cycle (Resource.quantity
  // is the recipe amount, e.g. 7th Hell's "Alcohol"). Empty for a business
  // with no stock mechanic. Actually moving a resource between businesses
  // (GTA Online-style supply runs) is future work -- this is the data shape
  // that's meant to hang off of.
  let inputs: array<ref<Resource>>;

  // Resources this business produces per production cycle, for a future
  // business to consume as an input. Empty if it only produces cash
  // (money is not a Resource -- see Resource.reds).
  let outputs: array<ref<Resource>>;

  let restockCostPer10Percent: Int32;
  let stockDecayPerDayPerActiveRole: Int32;
}
