// SPDX-License-Identifier: GPL-3.0-only
using PKHeX.Core;
using System.Text.Json;

try {
    var save = SaveUtil.GetVariantSAV(File.ReadAllBytes(args.Last()));
    if (save is null || save.Generation is < 1 or > 9 || !save.ChecksumsValid)
        throw new InvalidDataException("Choose an intact Generation 1-9 Pokemon save.");
    var occurrences = new Dictionary<string, int>();
    var rows = new List<object>();
    var invalid = new List<string>();
    var eggs = 0;
    void Read(PKM pk, string location) {
        if (pk.Species == 0) return;
        if (!pk.ChecksumValid) { invalid.Add(location); return; }
        if (pk.IsEgg) { eggs++; return; }
        var id = $"{pk.ID32:X8}-{pk.EncryptionConstant:X8}-{pk.PID:X8}";
        if (save.Generation <= 2) {
            var fingerprint = $"{pk.TID16}|{pk.OriginalTrainerName}|{pk.Species}|{pk.IV_ATK}|{pk.IV_DEF}|{pk.IV_SPE}|{pk.IV_SPA}";
            var hash = System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(fingerprint));
            var key = "GB-" + Convert.ToHexString(hash);
            var occurrence = occurrences.GetValueOrDefault(key);
            occurrences[key] = occurrence + 1;
            id = $"{key}-{occurrence}";
        }
        rows.Add(new { id, generation = save.Generation, sourceGame = save.Version.ToString(), tid16 = pk.TID16,
            sid16 = save.Generation >= 3 ? (int?)pk.SID16 : null, species = pk.Species,
            resourceSpecies = pk is PK9 ? SpeciesConverter.GetInternal9(pk.Species) : pk.Species,
            form = pk.Form, gender = pk.Gender,
            sweet = pk.Species == 869 && pk is IFormArgument a ? (int?)a.FormArgument : null,
            name = SpeciesName.GetSpeciesNameGeneration(pk.Species, 2, save.Generation), nickname = pk.Nickname,
            level = pk.CurrentLevel, shiny = pk.IsShiny, ot = pk.OriginalTrainerName,
            trainerId = pk.DisplayTID.ToString(pk.TrainerIDDisplayFormat == TrainerIDFormat.SixDigit ? "D6" : "D5"),
            nature = save.Generation <= 2 ? "Unrecorded" : pk.Nature.ToString(),
            origin = save.Generation <= 2 ? "Origin unrecorded" : GameInfo.Strings.gamelist[(int)pk.Version],
            ball = save.Generation <= 2 ? "Capture ball unrecorded" : GameInfo.Strings.balllist[pk.Ball],
            ballId = save.Generation <= 2 ? 0 : (int)pk.Ball, nicknamed = pk.IsNicknamed, location });
    }
    for (var i = 0; i < save.PartyCount; i++) Read(save.GetPartySlotAtIndex(i), $"Party {i + 1}");
    for (var i = 0; i < save.BoxCount * save.BoxSlotCount; i++)
        Read(save.GetBoxSlotAtIndex(i), $"Box {i / save.BoxSlotCount + 1}, slot {i % save.BoxSlotCount + 1}");
    Console.WriteLine(JsonSerializer.Serialize(new { game = save.Version.ToString(), trainer = save.OT, rows, invalid, eggs }));
} catch (Exception e) {
    Console.Error.WriteLine(e.Message);
    return 1;
}
return 0;
