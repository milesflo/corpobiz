module CorpoBiz

// Checks a BizDef's purchase prerequisites (quest/level/stat gates) against
// the player. Purchase price itself is checked separately at the point of
// transaction (see CorpoBiz.TryBuy) since it's a cost, not a gate.
public class CorpoBizPrereqs {

  public static func IsMet(game: GameInstance, player: ref<GameObject>, def: BizDef) -> Bool {
    for prereq in def.prereqs {
      if !CorpoBizPrereqs.IsPrereqMet(game, player, prereq) {
        return false;
      }
    }
    return true;
  }

  private static func IsPrereqMet(game: GameInstance, player: ref<GameObject>, prereq: BizPrereq) -> Bool {
    switch prereq.kind {
      case BizPrereqKind.Quest:
        return GameInstance.GetQuestsSystem(game).GetFact(prereq.questFact) > 0;
      case BizPrereqKind.Gig:
        let journal = GameInstance.GetJournalManager(game);
        let entry = journal.GetEntryByString(prereq.gigPath, "gameJournalQuest");
        return IsDefined(entry) && Equals(journal.GetEntryState(entry), gameJournalEntryState.Succeeded);
      case BizPrereqKind.Level:
        return RPGManager.GetStatValueFromObject(game, player, gamedataStatType.Level) >= Cast<Float>(prereq.requiredLevel);
      case BizPrereqKind.Stat:
        return RPGManager.GetStatValueFromObject(game, player, prereq.stat) >= prereq.requiredStatValue;
      default:
        return true;
    }
  }
}
