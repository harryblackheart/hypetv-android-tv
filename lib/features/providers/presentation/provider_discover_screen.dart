import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/features/providers/data/provider_service.dart';
import 'package:hypetv/features/providers/domain/provider_models.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class ProviderDiscoverScreen extends ConsumerStatefulWidget {
  const ProviderDiscoverScreen({super.key});
  @override ConsumerState<ProviderDiscoverScreen> createState()=>_ProviderDiscoverScreenState();
}

class _ProviderDiscoverScreenState extends ConsumerState<ProviderDiscoverScreen> {
  List<ProviderCatalog>? _catalogs;
  ProviderCatalog? _selected;
  List<ProviderItem>? _items;
  Object? _error;
  bool _loading=true;
  final _search=TextEditingController();

  @override void initState(){super.initState();unawaited(_loadCatalogs());}
  @override void dispose(){_search.dispose();super.dispose();}

  Future<void> _loadCatalogs() async {
    setState(() { _loading = true; _error = null; });
    try { final cats=await ref.read(providerServiceProvider).catalogs(); if(!mounted)return; setState(()=>_catalogs=cats); if(cats.isNotEmpty) await _openCatalog(cats.first); }
    catch(e){if(mounted)setState(()=>_error=e);} finally {if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _openCatalog(ProviderCatalog catalog,{String? search}) async {
    setState(() { _selected = catalog; _loading = true; _error = null; });
    try{final items=await ref.read(providerServiceProvider).catalog(catalog,search:search);if(mounted)setState(()=>_items=items);}catch(e){if(mounted)setState(()=>_error=e);}finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _openItem(ProviderItem item) async {
    if(item.type=='series'){
      setState(()=>_loading=true);
      try{final meta=await ref.read(providerServiceProvider).meta(item);if(!mounted)return;setState(()=>_loading=false);await showDialog<void>(context:context,builder:(context)=>_EpisodeDialog(meta:meta,onPlay:(episode)=>_play(item,episode.id,'series')));}catch(e){if(mounted)setState(() { _loading = false; _error = e; });}
      return;
    }
    await _play(item,item.id,item.type);
  }

  Future<void> _play(ProviderItem item,String contentId,String type) async {
    setState(()=>_loading=true);
    try{final source=await ref.read(providerServiceProvider).resolve(providerId:item.providerId,type:type,id:contentId);if(!mounted)return;setState(()=>_loading=false);context.push('/player',extra:PlayerArguments(source:source,item:ContentItem(id:'provider:${item.providerId}:$contentId',sourceId:contentId,playbackId:contentId,type:type=='series'?'series':'movie',title:item.title,subtitle:'Premium VOD',imageUrl:item.posterUrl??'')));}
    catch(e){if(mounted)setState(() { _loading = false; _error = e; });}
  }

  @override Widget build(BuildContext context){
    final catalogs=_catalogs??const <ProviderCatalog>[];
    final items=_items??const <ProviderItem>[];
    return Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(42,24,42,30),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const BrandLogo(),const SizedBox(width:28),const Text('Premium VOD',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:AppColors.red)),const Spacer(),TextButton.icon(onPressed:()=>context.go('/premium'),icon:const Icon(Icons.video_library_rounded),label:const Text('My Library')),const SizedBox(width:8),TextButton.icon(onPressed:()=>context.go('/settings'),icon:const Icon(Icons.settings_rounded),label:const Text('Settings'))]),
      const SizedBox(height:18),
      Row(children:[Expanded(child:TextField(controller:_search,onSubmitted:(q){if (_selected != null) { unawaited(_openCatalog(_selected!, search: q)); }},decoration:const InputDecoration(hintText:'Search provider catalogue',prefixIcon:Icon(Icons.search_rounded)))),const SizedBox(width:12),FilledButton.icon(onPressed:_selected==null?null:()=>_openCatalog(_selected!,search:_search.text),icon:const Icon(Icons.search_rounded),label:const Text('Search'))]),
      const SizedBox(height:18),
      SizedBox(height:52,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:catalogs.length,separatorBuilder: (_, _) =>const SizedBox(width:10),itemBuilder:(context,index){final c=catalogs[index];return ChoiceChip(label:Text('${c.providerName} · ${c.name}'),selected:_selected?.providerId==c.providerId&&_selected?.id==c.id,onSelected:(_)=>_openCatalog(c));})),
      const SizedBox(height:18),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator()):_error!=null?_ProviderError(error:_error!,retry:_loadCatalogs):catalogs.isEmpty?const _ProviderEmpty(title:'No content providers configured',message:'Add a compatible provider in HypeTV Control Centre → Settings → Content Providers.'):items.isEmpty?const _ProviderEmpty(title:'No items returned',message:'This provider catalogue did not return any items.'):GridView.builder(gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:240,childAspectRatio:.68,crossAxisSpacing:16,mainAxisSpacing:18),itemCount:items.length,itemBuilder:(context,index)=>_ProviderCard(item:items[index],autofocus:index==0,onTap:()=>_openItem(items[index])))),
    ]))));
  }
}

class _ProviderCard extends StatefulWidget{const _ProviderCard({required this.item,required this.onTap,required this.autofocus});final ProviderItem item;final VoidCallback onTap;final bool autofocus;@override State<_ProviderCard> createState()=>_ProviderCardState();}
class _ProviderCardState extends State<_ProviderCard>{bool focused=false;@override Widget build(BuildContext context){final item=widget.item;return Focus(autofocus:widget.autofocus,onFocusChange:(v)=>setState(()=>focused=v),child:InkWell(onTap:widget.onTap,borderRadius:BorderRadius.circular(14),child:AnimatedContainer(duration:const Duration(milliseconds:140),decoration:BoxDecoration(color:AppColors.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:focused?AppColors.red:Colors.white12,width:focused?3:1)),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Expanded(child:ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(13)),child:(item.posterUrl??'').isNotEmpty?Image.network(item.posterUrl!,fit:BoxFit.cover,errorBuilder: (_, _, _) =>const _PosterFallback()):const _PosterFallback())),Padding(padding:const EdgeInsets.all(12),child:Text(item.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))) ])))) ;}}
class _PosterFallback extends StatelessWidget{const _PosterFallback();@override Widget build(BuildContext context)=>Container(color:const Color(0xFF181818),child:const Center(child:Icon(Icons.movie_rounded,size:52,color:Colors.white24)));}
class _ProviderEmpty extends StatelessWidget{const _ProviderEmpty({required this.title,required this.message});final String title,message;@override Widget build(BuildContext context)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.hub_rounded,size:64,color:AppColors.red),const SizedBox(height:18),Text(title,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:10),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:AppColors.muted,fontSize:18))]));}
class _ProviderError extends StatelessWidget{const _ProviderError({required this.error,required this.retry});final Object error;final VoidCallback retry;@override Widget build(BuildContext context)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.cloud_off_rounded,size:58,color:AppColors.red),const SizedBox(height:16),Text(error is ProviderException?(error as ProviderException).message:'Provider unavailable'),const SizedBox(height:18),FilledButton(onPressed:retry,child:const Text('Try again'))]));}
class _EpisodeDialog extends StatelessWidget{const _EpisodeDialog({required this.meta,required this.onPlay});final ProviderMeta meta;final ValueChanged<ProviderEpisode> onPlay;@override Widget build(BuildContext context)=>Dialog(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900,maxHeight:650),child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(meta.item.title,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:16),Expanded(child:ListView.builder(itemCount:meta.videos.length,itemBuilder:(context,index){final e=meta.videos[index];return ListTile(autofocus:index==0,leading:e.thumbnail?.isNotEmpty==true?Image.network(e.thumbnail!,width:110,fit:BoxFit.cover,errorBuilder: (_, _, _) =>const Icon(Icons.play_circle_outline)):const Icon(Icons.play_circle_outline),title:Text(e.title),subtitle:Text([if(e.season!=null)'S${e.season}',if(e.episode!=null)'E${e.episode}'].join(' ')),onTap:(){Navigator.pop(context);onPlay(e);});}))])))) ;}
