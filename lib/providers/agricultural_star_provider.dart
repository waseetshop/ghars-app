import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/agricultural_star.dart';

final todayStarProvider =
    FutureProvider<AgriculturalStar?>((ref) async {
  final uri = Uri.parse(
    '${AppConstants.apiBaseUrl}/api/agricultural-stars/today',
  );

  final res = await http.get(uri);
  if (res.statusCode != 200) return null;

  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final data = body['data'];
  if (data == null) return null;

  return AgriculturalStar.fromJson(data as Map<String, dynamic>);
});
