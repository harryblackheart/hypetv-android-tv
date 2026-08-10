import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/providers/domain/provider_models.dart';
import 'package:hypetv/services/secure_storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

final providerServiceProvider = Provider<ProviderService>((ref) => ProviderService(ref.watch(httpClientProvider), ref.watch(secureStorageServiceProvider)));

class ProviderException implements Exception {
  const ProviderException(this.message, {this.code});
  final String message;
  final String? code;
  @override String toString() => message;
}

class ProviderService {
  const ProviderService(this._client,this._storage);
  final http.Client _client;
  final SecureStorageService _storage;

  Future<Map<String,String>> _headers() async {
    final token=await _storage.activationToken;
    if(token==null||token.isEmpty) throw const ProviderException('Your HypeTV session has expired.',code:'UNAUTHENTICATED');
    final info=await PackageInfo.fromPlatform();
    return {HttpHeaders.acceptHeader:'application/json',HttpHeaders.authorizationHeader:'Bearer $token','X-App-Version':info.version};
  }

  Future<List<ProviderCatalog>> catalogs() async {
    final r=await _client.get(Uri.parse('${AppConstants.apiBaseUrl}/api/providers/catalogs'),headers:await _headers()).timeout(const Duration(seconds:15));
    final b=_decode(r.body); _throw(r,b);
    final out=<ProviderCatalog>[];
    final providers=b['providers'];
    if(providers is List){for(final raw in providers.whereType<Map<String,dynamic>>()){
      final pid=raw['id']?.toString()??'', pname=raw['name']?.toString()??'Provider';
      final cats=raw['catalogs']; if(cats is List){for(final c in cats.whereType<Map<String,dynamic>>()){
        final id=c['id']?.toString()??'', type=c['type']?.toString()??''; if(id.isNotEmpty&&type.isNotEmpty) out.add(ProviderCatalog(providerId:pid,providerName:pname,id:id,type:type,name:c['name']?.toString()??id));
      }}
    }}
    return out;
  }

  Future<List<ProviderItem>> catalog(ProviderCatalog catalog,{String? search}) async {
    final uri=Uri.parse('${AppConstants.apiBaseUrl}/api/providers/${Uri.encodeComponent(catalog.providerId)}/catalog/${Uri.encodeComponent(catalog.type)}/${Uri.encodeComponent(catalog.id)}').replace(queryParameters:{if(search!=null&&search.trim().isNotEmpty)'search':search.trim()});
    final r=await _client.get(uri,headers:await _headers()).timeout(const Duration(seconds:20));
    final b=_decode(r.body); _throw(r,b); final items=b['items'];
    return items is List?items.whereType<Map<String,dynamic>>().map(ProviderItem.fromJson).where((x)=>x.id.isNotEmpty).toList(growable:false):const [];
  }

  Future<ProviderMeta> meta(ProviderItem item) async {
    final uri=Uri.parse('${AppConstants.apiBaseUrl}/api/providers/${Uri.encodeComponent(item.providerId)}/meta/${Uri.encodeComponent(item.type)}/${Uri.encodeComponent(item.id)}');
    final r=await _client.get(uri,headers:await _headers()).timeout(const Duration(seconds:20)); final b=_decode(r.body); _throw(r,b);
    final rawItem=b['item']; final videos=b['videos'];
    return ProviderMeta(item:rawItem is Map<String,dynamic>?ProviderItem.fromJson(rawItem):item,videos:videos is List?videos.whereType<Map<String,dynamic>>().map(ProviderEpisode.fromJson).where((x)=>x.id.isNotEmpty).toList(growable:false):const []);
  }

  Future<PlaybackSource> resolve({required String providerId,required String type,required String id}) async {
    final uri=Uri.parse('${AppConstants.apiBaseUrl}/api/providers/${Uri.encodeComponent(providerId)}/playback');
    final r=await _client.post(uri,headers:{...await _headers(),HttpHeaders.contentTypeHeader:'application/json'},body:jsonEncode({'type':type,'id':id,'stream_index':0})).timeout(const Duration(seconds:30));
    final b=_decode(r.body); _throw(r,b); final p=b['playback']; if(p is! Map<String,dynamic>) throw const ProviderException('HypeTV could not prepare this source.');
    final url=p['url']?.toString()??''; if(url.isEmpty) throw const ProviderException('No playable source was returned.');
    final headers=<String,String>{}; final rh=p['headers']; if(rh is Map){for(final e in rh.entries) headers[e.key.toString()]=e.value.toString();}
    return PlaybackSource(url:url,headers:headers);
  }

  Map<String,dynamic> _decode(String source){try{final d=jsonDecode(source);return d is Map<String,dynamic>?d:const {}}catch(_){return const {}}}
  void _throw(http.Response r,Map<String,dynamic> b){if(r.statusCode>=200&&r.statusCode<300&&b['success']!=false)return;final code=b['code']?.toString();throw ProviderException(b['message']?.toString()??'Content provider is unavailable.',code:code);}
}
