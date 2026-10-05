import '../../storage/storage_service.dart';
import '../../storage/models/pet_pack_entry.dart';

/// Repository for querying and managing installed pet packs.
class PetPackRepository {
  List<PetPackEntry> listPacks() {
    return StorageService.readPacks();
  }

  Future<void> addPack(PetPackEntry entry) async {
    StorageService.addPack(entry);
  }
}
