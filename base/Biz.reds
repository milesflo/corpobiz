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
  Stat = 2,
  Gig = 3
}

// A single purchase gate. Only the field(s) matching `kind` are meaningful.
public struct BizPrereq {
  let kind: BizPrereqKind;

  // Quest: a Facts-system flag that must be >= 1. Kept for prereqs with no
  // real vanilla quest behind them (a self-asserted "pretend this is done"
  // flag) -- for a real vanilla quest/gig, prefer Gig below instead, which
  // checks the actual journal state rather than trusting a hand-set Fact.
  let questFact: CName;

  // Gig: the quest/gig's real internal resource path (e.g.
  // "quests/street_stories/city_center/downtown/sts_cct_dtn_02" for "An
  // Inconvenient Killer"), confirmed met once JournalManager reports that
  // path's entry state as Succeeded. See CorpoBizPrereqs.IsPrereqMet.
  let gigPath: String;

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

// Field order here is NOT cosmetic: every array field is grouped at the
// end, after every scalar/Vector4 field, deliberately. Debugging found
// terminalPosition reading back as zero at runtime for every module --
// confirmed (via an isolated, Def()-free Vector4 construct-and-read) to
// NOT be a general Vector4 bug, and confirmed (by reordering the writes
// inside Def(), which did nothing) to NOT be about assignment order
// either. The remaining difference was terminalPosition's own
// *declared* position in this struct, sandwiched between two array
// fields (prereqs before it, roles after). Moving every array field to
// the end, so no scalar/Vector4 field is ever declared adjacent to one,
// is the fix being tested -- if this works, treat "no array field next
// to a scalar/Vector4 field in the same struct" as a hard rule for any
// future struct in this codebase, not just this one.
public struct BizDef {
  let id: CName;
  let displayName: String;
  let purchasePrice: Int32;
  let terminalPosition: Vector4;
  let restockCostPer10Percent: Int32;
  let stockDecayPerDayPerActiveRole: Int32;

  let prereqs: array<BizPrereq>;

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
}
