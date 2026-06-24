import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';

class MemoryService {
  static const _profileKey = 'worldos_user_profile';
  static const _timeSavedKey = 'worldos_time_saved';

  late SharedPreferences _prefs;
  UserProfile _profile = UserProfile();
  TimeSaved _timeSaved = TimeSaved();

  UserProfile get profile => _profile;
  TimeSaved get timeSaved => _timeSaved;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadProfile();
    _loadTimeSaved();
  }

  void _loadProfile() {
    final json = _prefs.getString(_profileKey);
    if (json != null) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _profile = UserProfile(
          name: map['name'] ?? '',
          email: map['email'] ?? '',
          phone: map['phone'] ?? '',
          budget: map['budget'] ?? '',
          location: map['location'] ?? '',
          preferences: map['preferences'] ?? '',
          writingTone: map['writingTone'] ?? 'professional',
          riskTolerance: map['riskTolerance'] ?? 'moderate',
          savedFields: Map<String, String>.from(map['savedFields'] ?? {}),
          pastIntents: List<String>.from(map['pastIntents'] ?? []),
        );
      } catch (e) {
        _profile = UserProfile();
      }
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    await _prefs.setString(_profileKey, jsonEncode({
      'name': profile.name,
      'email': profile.email,
      'phone': profile.phone,
      'budget': profile.budget,
      'location': profile.location,
      'preferences': profile.preferences,
      'writingTone': profile.writingTone,
      'riskTolerance': profile.riskTolerance,
      'savedFields': profile.savedFields,
      'pastIntents': profile.pastIntents,
    }));
  }

  void _loadTimeSaved() {
    final json = _prefs.getString(_timeSavedKey);
    if (json != null) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _timeSaved = TimeSaved(
          totalMinutes: map['totalMinutes'] ?? 0,
          tasksCompleted: map['tasksCompleted'] ?? 0,
          formsFilled: map['formsFilled'] ?? 0,
          comparisonsDone: map['comparisonsDone'] ?? 0,
          badChoicesAvoided: map['badChoicesAvoided'] ?? 0,
          pagesRead: map['pagesRead'] ?? 0,
        );
      } catch (e) {
        _timeSaved = TimeSaved();
      }
    }
  }

  Future<void> saveTimeSaved(TimeSaved ts) async {
    _timeSaved = ts;
    await _prefs.setString(_timeSavedKey, jsonEncode({
      'totalMinutes': ts.totalMinutes,
      'tasksCompleted': ts.tasksCompleted,
      'formsFilled': ts.formsFilled,
      'comparisonsDone': ts.comparisonsDone,
      'badChoicesAvoided': ts.badChoicesAvoided,
      'pagesRead': ts.pagesRead,
    }));
  }

  void addPastIntention(String intention) {
    if (intention.trim().isEmpty) return;
    if (!_profile.pastIntents.contains(intention)) {
      _profile.pastIntents.insert(0, intention);
      if (_profile.pastIntents.length > 50) {
        _profile.pastIntents = _profile.pastIntents.sublist(0, 50);
      }
      saveProfile(_profile);
    }
  }
}
