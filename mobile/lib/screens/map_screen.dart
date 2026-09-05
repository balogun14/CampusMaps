import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_request.dart';
import '../models/route_response.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import '../services/recording_service.dart';
import '../services/routing_service.dart';
import '../models/recorded_activity.dart';
import '../utils/polyline_decoder.dart';
import '../theme.dart';
import '../widgets/directions_panel.dart';
import '../widgets/navigation_banner.dart';
import '../widgets/recording_controls.dart';
import '../widgets/recording_stats_card.dart';
import '../widgets/street_preview.dart';
import '../widgets/user_location_marker.dart';
import 'activity_history_screen.dart';

enum MapMode { explore, navigate, record }
enum MapStyle { editorial, light, dark, satellite }

class MapScreen extends StatefulWidget {
  final RoutingService routingService;
  const MapScreen({super.key, required this.routingService});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _mapController = MapController();
  final LocationService _locationService = LocationService();
  final RecordingService _recordingService = RecordingService();
  NavigationService? _navigationService;
  MapMode _mode = MapMode.explore;
  String _costing = 'campus_pedestrian';
  bool _avoidStairs = true;
  double _walkingSpeed = 5.0;
  LatLng? _origin; LatLng? _destination;
  RouteResponse? _routeResponse;
  List<LatLng>? _routeLatLngs;
  bool _loading = false; String? _error;
  bool _showDirections = false;
  RouteStep? _selectedStep;
  MapStyle _mapStyle = MapStyle.editorial;
  bool get _isDark => _mapStyle == MapStyle.dark;
  bool get _isEditorial => _mapStyle == MapStyle.editorial;
  LatLng? _currentLocation;
  double _currentHeading = 0;
  bool _gpsEnabled = false;
  StreamSubscription<LatLng>? _posSub;
  StreamSubscription<double>? _headingSub;
  StreamSubscription<NavigationUpdate>? _navSub;
  NavigationUpdate? _navUpdate;
  double _rotation = 0;
  RecordingStats? _recordingStats;
  List<LatLng> _recordingTrail = [];
  StreamSubscription<RecordingState>? _recStateSub;
  StreamSubscription<RecordingStats>? _recStatsSub;
  static const _medilagCenter = LatLng(6.515, 3.350);

  @override void initState(){ super.initState(); _origin=const LatLng(6.5135,3.3515); _destination=const LatLng(6.5165,3.3490); _initGps(); }
  Future<void> _initGps() async {
    final enabled = await _locationService.isGpsEnabled();
    final granted = await _locationService.requestPermission();
    if(mounted) setState(()=> _gpsEnabled=enabled&&granted);
    if(enabled&&granted){ final pos=await _locationService.getCurrentPosition(); if(mounted&&pos!=null) setState(()=> _currentLocation=pos); }
  }
  void _startGpsListening(){
    _posSub?.cancel(); _headingSub?.cancel();
    _locationService.startListening(distanceFilter:3);
    _posSub=_locationService.positionStream.listen((pos){
      if(!mounted) return; _currentLocation=pos;
      if(_mode==MapMode.navigate && _navigationService!=null){ _navUpdate=_navigationService!.updatePosition(pos.latitude,pos.longitude,heading:_currentHeading); if(_navUpdate?.arrived==true) _onArrival(); }
      if(_mode==MapMode.record && _recordingService.isRecording){ _recordingService.addPoint(pos.latitude,pos.longitude,heading:_currentHeading); _recordingTrail=_recordingService.points.map((p)=>LatLng(p.lat,p.lng)).toList(); }
      setState((){});
    });
    _headingSub=_locationService.headingStream.listen((h){ if(mounted) setState(()=>_currentHeading=h); });
  }
  void _stopGpsListening(){ _posSub?.cancel(); _posSub=null; _headingSub?.cancel(); _headingSub=null; _locationService.stopListening(); }
  void _enterNavigationMode(){
    if(_routeLatLngs==null||_routeResponse==null) return;
    final nav=NavigationService(); nav.init(_routeResponse!); _navigationService=nav;
    _navSub=nav.updates.listen((u){ if(mounted) setState(()=>_navUpdate=u); });
    _startGpsListening(); setState(()=> _mode=MapMode.navigate); _fitRouteInView();
  }
  void _exitNavigation(){ _navSub?.cancel(); _navSub=null; _navigationService?.dispose(); _navigationService=null; _navUpdate=null; _stopGpsListening(); setState(()=>_mode=MapMode.explore); }
  void _onArrival(){ _navSub?.cancel(); _navSub=null; }
  void _startRecording(){ _recordingTrail.clear(); _recordingService.start(); _recStateSub=_recordingService.stateStream.listen((_)=> mounted?setState(()=>{}):null); _recStatsSub=_recordingService.statsStream.listen((s)=> mounted?setState(()=>_recordingStats=s):null); _startGpsListening(); setState(()=>_mode=MapMode.record); }
  void _pauseRecording()=> _recordingService.pause();
  void _resumeRecording()=> _recordingService.resume();
  Future<void> _stopRecording() async {
    final nameController=TextEditingController(text:'My Walk'); ActivityType selectedType=ActivityType.walk;
    final bg=_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white);
    final txt=_isEditorial?Editorial.ink:(_isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    final type=await showDialog<ActivityType>(context:context, builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      backgroundColor:bg,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      title:Text('Save walk', style:TextStyle(fontWeight:FontWeight.w700, fontSize:16, color:txt, fontFamily:'serif')),
      content:Column(mainAxisSize:MainAxisSize.min, children:[
        TextField(controller:nameController, style:TextStyle(color:txt), decoration:InputDecoration(labelText:'Name this walk', prefixIcon:Icon(Icons.edit_outlined, color:sub))),
        const SizedBox(height:12),
        DropdownButtonFormField<ActivityType>(initialValue:selectedType, dropdownColor:bg, decoration:const InputDecoration(labelText:'Type'), items:const[DropdownMenuItem(value:ActivityType.walk, child:Text('Campus walk')),DropdownMenuItem(value:ActivityType.run, child:Text('Run')),DropdownMenuItem(value:ActivityType.hike, child:Text('Wander'))], onChanged:(v){ if(v!=null) setD(()=>selectedType=v); }),
      ]), actions:[TextButton(onPressed:()=>Navigator.pop(ctx), child:const Text('Discard')), FilledButton(onPressed:()=>Navigator.pop(ctx,selectedType), style:FilmedStyle.call(isDark:_isDark, isEditorial:_isEditorial), child:const Text('Save'))],
    )));
    await _recordingService.stop(name:type==null?'Discarded':nameController.text, type:type??ActivityType.walk);
    _recStateSub?.cancel(); _recStatsSub?.cancel(); _stopGpsListening(); _recordingTrail.clear(); _recordingStats=null;
    if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(type==null?'Discarded':'Walk saved — nice wander'), backgroundColor:const Color(0xFF323232))); setState(()=>_mode=MapMode.explore); }
  }
  void _fitRouteInView(){ if(_routeLatLngs==null||_routeLatLngs!.isEmpty) return; _mapController.fitCamera(CameraFit.bounds(bounds:LatLngBounds.fromPoints(_routeLatLngs!), padding:const EdgeInsets.all(80))); }
  void _onMapTap(TapPosition _, LatLng p){ if(_mode!=MapMode.explore) return; if(_origin==null) setState(()=>_origin=p); else if(_destination==null) setState(()=>_destination=p); else setState((){ _origin=p; _destination=null; _routeResponse=null; _routeLatLngs=null; _showDirections=false; }); }
  Future<void> _fetchRoute() async {
    if(_origin==null||_destination==null) return;
    setState(()=> _loading=true);
    try{
      final req=RouteRequest(originLat:_origin!.latitude, originLng:_origin!.longitude, destLat:_destination!.latitude, destLng:_destination!.longitude, costing:_costing, avoidStairs:_avoidStairs, walkingSpeedKmh:_walkingSpeed);
      final resp=await widget.routingService.getRoute(req);
      final pts=decodePolyline(resp.encodedPolyline).map((p)=>LatLng(p.lat,p.lng)).toList();
      setState(()=> _routeResponse=resp);
      setState(()=> _routeLatLngs=pts);
      setState(()=> _loading=false);
      setState(()=> _showDirections=true);
      if(pts.isNotEmpty) _mapController.fitCamera(CameraFit.bounds(bounds:LatLngBounds.fromPoints(pts), padding:const EdgeInsets.fromLTRB(40,180,40,260)));
    }catch(e){
      final msg=e.toString().toLowerCase();
      final isNet=msg.contains('api key')||msg.contains('connection')||msg.contains('socket')||msg.contains('refused')||msg.contains('timeout');
      if(isNet){
        final mock=_mockRoute(); final pts=decodePolyline(mock.encodedPolyline).map((p)=>LatLng(p.lat,p.lng)).toList();
        setState(()=> _routeResponse=mock);
        setState(()=> _routeLatLngs=pts);
        setState(()=> _loading=false);
        setState(()=> _showDirections=true);
        if(pts.isNotEmpty) _mapController.fitCamera(CameraFit.bounds(bounds:LatLngBounds.fromPoints(pts), padding:const EdgeInsets.fromLTRB(40,180,40,260)));
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Offline demo — editorial route shown'), backgroundColor:Color(0xFF323232)));
        return;
      }
      setState(()=> _error=e.toString());
      setState(()=> _loading=false);
    } finally { if(mounted) setState(()=> _error=_error); }
  }
  RouteResponse _mockRoute(){
    final o=_origin!, d=_destination!; final mid=LatLng((o.latitude+d.latitude)/2,(o.longitude+d.longitude)/2); final dist=const Distance().as(LengthUnit.Meter,o,d);
    final steps=[RouteStep(stepNumber:1,instruction:'Stroll north through the colonnade',streetName:'Campus Walk',lat:o.latitude,lng:o.longitude,encodedPolyline:'',distanceMeters:dist*0.4,durationSeconds:dist*0.72,direction:'north',isCustomPath:true), RouteStep(stepNumber:2,instruction:'Bear right past the Library',streetName:'Scholars Row',lat:mid.latitude,lng:mid.longitude,encodedPolyline:'',distanceMeters:dist*0.35,durationSeconds:dist*0.63,direction:'east',isCustomPath:false), RouteStep(stepNumber:3,instruction:'Arrive — you’re here',streetName:'MEDILAG quad',lat:d.latitude,lng:d.longitude,encodedPolyline:'',distanceMeters:dist*0.25,durationSeconds:dist*0.45,direction:'north',isCustomPath:true)];
    return RouteResponse(encodedPolyline:_encode([o,mid,d]), summary:RouteSummary(distanceMeters:dist,durationSeconds:dist*1.2/1.4,distanceKm:dist/1000,durationFormatted:'${(dist/75).round()} min'), steps:steps);
  }
  String _encode(List<LatLng> pts){ String enc(int v){ v=v<0?~(v<<1):(v<<1); var r=''; while(v>=0x20){ r+=String.fromCharCode((0x20|(v&0x1f))+63); v>>=5; } r+=String.fromCharCode(v+63); return r; } var la=0, ln=0; var o=''; for(final p in pts){ final lat=(p.latitude*1e5).round(), lng=(p.longitude*1e5).round(); o+=enc(lat-la)+enc(lng-ln); la=lat; ln=lng; } return o; }
  void _centerOnUser(){ if(_currentLocation!=null) _mapController.move(_currentLocation!,17); }
  void _clearRoute(){ setState(()=> _origin=null); setState(()=> _destination=null); setState(()=> _routeResponse=null); setState(()=> _routeLatLngs=null); setState(()=> _showDirections=false); setState(()=> _error=null); setState(()=> _selectedStep=null); }
  void _onStepTap(RouteStep s){ setState(()=> _selectedStep=s); _mapController.move(LatLng(s.lat,s.lng),19); }
  String _short(LatLng? p)=> p==null?'':'${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';

  @override Widget build(BuildContext context){
    if(_mode==MapMode.navigate) return _buildNav();
    if(_mode==MapMode.record) return _buildRecord();
    return _buildExplore();
  }

  Widget _buildExplore(){
    final hasRoute=_routeLatLngs!=null && _routeResponse!=null;
    final scaffoldBg=_isEditorial?Editorial.paper:(_isDark?DarkPremium.bg:GoogleColors.surface);
    return Scaffold(
      backgroundColor:scaffoldBg,
      body:Stack(children:[
        _buildMap(),
        Positioned(top:MediaQuery.of(context).padding.top+8, left:8,right:8, child:_buildTopCard()),
        Positioned(top:MediaQuery.of(context).padding.top+ (_origin!=null||_destination!=null? 152: 66), left:8, child:_buildStyleSwitcher()),
        Positioned(right:8, bottom:hasRoute? 220: 110, child:_buildRightControls()),
        if(_origin==null||_destination==null) Positioned(top:MediaQuery.of(context).padding.top+92, left:16,right:16, child:_buildHint()),
        if(_error!=null) Positioned(top:MediaQuery.of(context).padding.top+92, left:16,right:16, child:_buildError()),
        if(_selectedStep!=null) Positioned(bottom:0,left:0,right:0, child:StreetPreview(step:_selectedStep!, onClose:()=>setState(()=>_selectedStep=null), isDark:_isDark, isEditorial:_isEditorial))
        else if(_showDirections&&_routeResponse!=null) Positioned(bottom:0,left:0,right:0, child:DirectionsPanel(response:_routeResponse!, onDismiss:()=>setState(()=>_showDirections=false), onStartNav:_enterNavigationMode, onStepTap:_onStepTap, selectedStepIndex:_selectedStep==null?null:_routeResponse!.steps.indexWhere((s)=>s.stepNumber==_selectedStep!.stepNumber), isDark:_isDark, isEditorial:_isEditorial))
        else Positioned(bottom:0,left:0,right:0, child:_buildBottomBar()),
      ]),
    );
  }

  // Editorial top card — warm paper, serif title
  Widget _buildTopCard(){
    final hasPin=_origin!=null||_destination!=null;
    final bg=_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white);
    final border=_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border);
    final txt=_isEditorial?Editorial.ink:(_isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    final div=_isEditorial?Editorial.divider:(_isDark?DarkPremium.divider:GoogleColors.divider);
    if(hasPin){
      return Material(elevation:6, shadowColor:Colors.black26, borderRadius:BorderRadius.circular(16), child:Container(decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(16), border:Border.all(color:border)), child:Column(mainAxisSize:MainAxisSize.min, children:[
        Padding(padding:const EdgeInsets.fromLTRB(8,8,8,0), child:Row(children:[
          IconButton(icon:Icon(Icons.arrow_back, color:sub), onPressed:_clearRoute),
          Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal, child:Row(children:[
            _chip(Icons.directions_walk,'Stroll',_costing.contains('pedestrian')),
            _chip(Icons.directions_bike_outlined,'Cycle',_costing=='bicycle'),
            _chip(Icons.directions_car_outlined,'Drive',_costing=='auto'),
          ]))),
          IconButton(icon:Icon(Icons.tune, color:sub, size:20), onPressed:()=>_showSettings()),
        ])),
        Divider(height:1, color:div),
        Padding(padding:const EdgeInsets.fromLTRB(16,14,12,14), child:Row(children:[
          Column(children:[Container(width:10,height:10, decoration:BoxDecoration(color:bg, shape:BoxShape.circle, border:Border.all(color:_isEditorial?Editorial.sage:GoogleColors.textTertiary, width:2.2))), Container(width:2,height:22,color:border), Container(width:10,height:10, decoration:BoxDecoration(color:_isEditorial?Editorial.coral:GoogleColors.red, shape:BoxShape.circle))]),
          const SizedBox(width:14),
          Expanded(child:Column(children:[
            _field(value:_short(_origin), hint:'Where from?', hintColor:sub, textColor:txt, showClear:_origin!=null, onClear:()=> setState(()=>_origin=null)),
            Divider(height:16, color:div),
            _field(value:_short(_destination), hint:'Where to?', hintColor:sub, textColor:txt, showClear:_destination!=null, onClear:()=> setState(()=>_destination=null)),
          ])),
          IconButton(icon:Icon(Icons.swap_vert, color:_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.blue)), onPressed:(){ if(_origin!=null&&_destination!=null){ final t=_origin; setState(()=>_origin=_destination); setState(()=>_destination=t); if(_routeLatLngs!=null) _fetchRoute(); }}),
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(16,0,16,14), child:Row(children:[
          Expanded(child:FilmedButton(icon:_loading? const SizedBox(width:16,height:16, child:CircularProgressIndicator(strokeWidth:2, color:Colors.white)):const Icon(Icons.near_me, size:18), label:Text(_loading?'Charting…':'Get directions'), onPressed:(_origin!=null&&_destination!=null&&!_loading)?_fetchRoute:null, isDark:_isDark, isEditorial:_isEditorial)),
          const SizedBox(width:10),
          OutlinedButton(onPressed:_clearRoute, style:OutlinedButton.styleFrom(side:BorderSide(color:border), foregroundColor:sub, padding:const EdgeInsets.symmetric(horizontal:16, vertical:12), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24))), child:const Text('Clear')),
        ])),
      ])));
    }
    // Editorial search — large serif R
    return Material(elevation:6, shadowColor:Colors.black26, borderRadius:BorderRadius.circular(28), child:Container(height:52, decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(28), border:Border.all(color:border)), child:Row(children:[
      const SizedBox(width:6), IconButton(icon:Icon(Icons.menu, color:sub), onPressed:()=>_showSettings()),
      Expanded(child:TextField(enabled:false, decoration:InputDecoration(hintText:'Search RunIt — buildings, halls, gates', hintStyle:TextStyle(color:sub, fontSize:13, fontStyle:FontStyle.italic), border:InputBorder.none, filled:false, contentPadding:const EdgeInsets.symmetric(vertical:12)))),
      Container(width:1,height:24,color:div), const SizedBox(width:6),
      IconButton(icon:Icon(Icons.search, color:_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.blue)), onPressed:(){}),
      Container(margin:const EdgeInsets.only(right:8), width:34,height:34, decoration:BoxDecoration(color:_isEditorial?Editorial.navy:(_isDark?DarkPremium.neonBlue:const Color(0xFF8AB4F8)), shape:BoxShape.circle), child:Center(child:Text('R', style:TextStyle(color:_isEditorial?Colors.white:(_isDark?DarkPremium.bg:Colors.white), fontWeight:FontWeight.w900, fontFamily:'serif', fontSize:16)))),
    ])));
  }
  Widget _field({required String value, required String hint, required Color hintColor, required Color textColor, bool showClear=false, VoidCallback? onClear}){
    final empty=value.isEmpty;
    return Row(children:[Expanded(child:Text(empty?hint:value, style:TextStyle(fontSize:14, color:empty?hintColor:textColor, fontStyle:empty?FontStyle.italic:FontStyle.normal), overflow:TextOverflow.ellipsis)), if(showClear) GestureDetector(onTap:onClear, child:Icon(Icons.close, size:18, color:hintColor))]);
  }
  Widget _chip(IconData icon, String label, bool sel){
    final selBg=_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.blue);
    final selFg=_isDark||_isEditorial?Colors.white:Colors.white;
    return Padding(padding:const EdgeInsets.only(right:6), child:ChoiceChip(
      selected:sel, onSelected:(_){ if(label=='Stroll') setState(()=>_costing='campus_pedestrian'); if(label=='Cycle') setState(()=>_costing='bicycle'); if(label=='Drive') setState(()=>_costing='auto'); if(_routeLatLngs!=null) _fetchRoute(); },
      label:Row(mainAxisSize:MainAxisSize.min, children:[Icon(icon, size:16, color:sel?selFg:(_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary))), const SizedBox(width:4), Text(label, style:TextStyle(fontSize:12, fontWeight:FontWeight.w600, color:sel?selFg:(_isEditorial?Editorial.ink:(_isDark?DarkPremium.textPrimary:GoogleColors.textPrimary))))]),
      selectedColor:selBg, backgroundColor:_isEditorial?Editorial.paperDark:(_isDark?DarkPremium.cardElevated:Colors.white), side:BorderSide(color:sel?selBg:(_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border))), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)), showCheckmark:false, padding:const EdgeInsets.symmetric(horizontal:10, vertical:4),
    ));
  }

  Widget _buildStyleSwitcher(){
    return Material(elevation:4, borderRadius:BorderRadius.circular(20), child:Container(decoration:BoxDecoration(color:_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white), borderRadius:BorderRadius.circular(20), border:Border.all(color:_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border))), child:Row(mainAxisSize:MainAxisSize.min, children:[
      _seg('Editorial', Icons.auto_stories, MapStyle.editorial),
      _seg('Light', Icons.light_mode, MapStyle.light),
      _seg('Dark', Icons.dark_mode, MapStyle.dark),
      _seg('Satellite', Icons.satellite_alt, MapStyle.satellite),
    ])));
  }
  Widget _seg(String label, IconData icon, MapStyle style){
    final sel=_mapStyle==style;
    Color bg; Color fg;
    if(sel){ bg=_isEditorial?Editorial.navy:(_isDark?DarkPremium.neonBlue:GoogleColors.blue); fg=Colors.white; }
    else { bg=Colors.transparent; fg=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary); }
    return GestureDetector(onTap:()=> setState(()=>_mapStyle=style), child:Container(padding:const EdgeInsets.symmetric(horizontal:10, vertical:7), decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(20)), child:Row(mainAxisSize:MainAxisSize.min, children:[Icon(icon, size:13, color:fg), const SizedBox(width:4), Text(label, style:TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:fg))])) );
  }

  Widget _buildHint(){
    final bg=_isEditorial?Editorial.navy:(_isDark?DarkPremium.card:const Color(0xFF323232));
    final txt=Colors.white; final accent=_isEditorial?Editorial.mustard:(_isDark?DarkPremium.neonBlue:const Color(0xFF8AB4F8));
    return Material(elevation:4, borderRadius:BorderRadius.circular(24), child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10), decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(24)), child:Row(mainAxisSize:MainAxisSize.min, children:[
      Icon(_origin==null?Icons.touch_app:Icons.place_outlined, color:accent, size:16), const SizedBox(width:8),
      Text(_origin==null?'Tap map to set start':'Tap for destination', style:TextStyle(color:txt, fontSize:13, fontWeight:FontWeight.w600, fontStyle:FontStyle.italic)),
      if(_origin!=null||_destination!=null) GestureDetector(onTap:_clearRoute, child:Padding(padding:const EdgeInsets.only(left:12), child:Text('Clear', style:TextStyle(color:accent, fontSize:13, fontWeight:FontWeight.w700)))),
    ])));
  }
  Widget _buildError(){
    final bg=_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white);
    final accent=_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.red);
    final txt=_isEditorial?Editorial.ink:(_isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    return Material(elevation:4, borderRadius:BorderRadius.circular(12), child:Container(padding:const EdgeInsets.all(12), decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(12), border:Border(left:BorderSide(color:accent, width:4))), child:Row(children:[
      Icon(Icons.error_outline, color:accent, size:20), const SizedBox(width:8),
      Expanded(child:Text(_error!, style:TextStyle(fontSize:13, color:txt))),
      GestureDetector(onTap:()=>setState(()=>_error=null), child:Icon(Icons.close, size:18, color:sub)),
    ])));
  }
  Widget _buildBottomBar(){
    final bg=_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white);
    final border=_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border);
    final txt=_isEditorial?Editorial.ink:(_isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    final surf=_isEditorial?Editorial.paperDark:(_isDark?DarkPremium.cardElevated:GoogleColors.surface);
    final div=_isEditorial?Editorial.divider:(_isDark?DarkPremium.divider:GoogleColors.divider);
    return Container(decoration:BoxDecoration(color:bg, borderRadius:const BorderRadius.vertical(top:Radius.circular(20)), border:Border(top:BorderSide(color:border)), boxShadow:[BoxShadow(color:Colors.black.withAlpha(18), blurRadius:12, offset:const Offset(0,-2))]), child:SafeArea(top:false, child:Column(mainAxisSize:MainAxisSize.min, children:[
      Container(margin:const EdgeInsets.only(top:8), width:32,height:4, decoration:BoxDecoration(color:div, borderRadius:BorderRadius.circular(2))),
      Padding(padding:const EdgeInsets.fromLTRB(16,14,16,8), child:Row(children:[
        _quick(Icons.explore_outlined,'Explore', _isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.blue), surf, border, txt, (){}),
        const SizedBox(width:8), _quick(Icons.bookmark_border,'Saved', sub, surf, border, txt, ()=> Navigator.push(context, MaterialPageRoute(builder:(_)=> ActivityHistoryScreen(recordingService:_recordingService)))),
        const SizedBox(width:8), _quick(Icons.add_location_alt_outlined,'Contribute', sub, surf, border, txt, (){}),
        const Spacer(),
        GestureDetector(onTap:_gpsEnabled?_startRecording:_showGps, child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:9), decoration:BoxDecoration(color:_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.red), borderRadius:BorderRadius.circular(20), boxShadow:[BoxShadow(color:(_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.red)).withAlpha(50), blurRadius:10)]), child:Row(mainAxisSize:MainAxisSize.min, children:[const Icon(Icons.fiber_manual_record, size:14, color:Colors.white), const SizedBox(width:6), Text('Record walk', style:TextStyle(color:Colors.white, fontWeight:FontWeight.w700, fontSize:13, fontStyle:FontStyle.italic))]))),
      ])),
      Divider(height:1, color:div),
      Padding(padding:const EdgeInsets.fromLTRB(16,12,16,14), child:Row(children:[
        Container(padding:const EdgeInsets.all(7), decoration:BoxDecoration(color:surf, borderRadius:BorderRadius.circular(10), border:Border.all(color:border)), child:Icon(Icons.school_outlined, size:18, color:sub)),
        const SizedBox(width:10), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text('MEDILAG — Editorial', style:TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:txt, fontFamily:'serif')), Text('College of Medicine, University of Lagos • curated campus map', style:TextStyle(fontSize:11, color:sub, fontStyle:FontStyle.italic))])),
        TextButton(onPressed:()=>_showSettings(), child:Text('Options', style:TextStyle(color:_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.blue), fontSize:13, fontWeight:FontWeight.w700))),
      ])),
    ])));
  }
  Widget _quick(IconData icon, String label, Color iconColor, Color bg, Color border, Color txt, VoidCallback onTap){
    return InkWell(onTap:onTap, borderRadius:BorderRadius.circular(20), child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(20), border:Border.all(color:border)), child:Row(mainAxisSize:MainAxisSize.min, children:[Icon(icon, size:14, color:iconColor), const SizedBox(width:4), Text(label, style:TextStyle(fontSize:11, color:txt, fontWeight:FontWeight.w700))])));
  }
  Widget _buildRightControls(){
    final cardBg=_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white);
    final iconCol=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    final neon=_isEditorial?Editorial.coral:DarkPremium.neonBlue;
    return Column(mainAxisSize:MainAxisSize.min, children:[
      Material(elevation:4, shape:const CircleBorder(), child:InkWell(onTap:()=> setState(()=> _mapStyle = _mapStyle==MapStyle.editorial? MapStyle.dark: MapStyle.editorial), customBorder:const CircleBorder(), child:Container(width:40,height:40, decoration:BoxDecoration(color:cardBg, shape:BoxShape.circle, border:Border.all(color:_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border))), child:Icon(_isEditorial?Icons.dark_mode:Icons.auto_stories, size:18, color:_isEditorial?Editorial.coral:iconCol)))),
      const SizedBox(height:8),
      if(_rotation.abs()>2) Padding(padding:const EdgeInsets.only(bottom:8), child:_fab(Icons.explore, ()=>{ _mapController.rotate(0), setState(()=>_rotation=0)}, iconColor:neon, bg:cardBg)),
      _fab(Icons.my_location, _centerOnUser, iconColor:neon, bg:cardBg),
      const SizedBox(height:8),
      Material(elevation:4, borderRadius:BorderRadius.circular(12), child:Column(children:[
        InkWell(onTap:()=> _mapController.move(_mapController.camera.center, _mapController.camera.zoom+1), child:Container(width:40,height:40, decoration:BoxDecoration(color:cardBg, borderRadius:const BorderRadius.vertical(top:Radius.circular(12))), child:Icon(Icons.add, size:20, color:iconCol))),
        Container(height:1, width:40, color:_isEditorial?Editorial.divider:(_isDark?DarkPremium.divider:GoogleColors.divider)),
        InkWell(onTap:()=> _mapController.move(_mapController.camera.center, _mapController.camera.zoom-1), child:Container(width:40,height:40, decoration:BoxDecoration(color:cardBg, borderRadius:const BorderRadius.vertical(bottom:Radius.circular(12))), child:Icon(Icons.remove, size:20, color:iconCol))),
      ])),
    ]);
  }
  Widget _fab(IconData icon, VoidCallback onTap, {Color? iconColor, Color? bg}){
    return Material(elevation:4, shape:const CircleBorder(), child:InkWell(onTap:onTap, customBorder:const CircleBorder(), child:Container(width:40,height:40, decoration:BoxDecoration(color:bg??(_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white)), shape:BoxShape.circle, border:Border.all(color:_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border))), child:Icon(icon, size:20, color:iconColor))));
  }
  void _showSettings(){
    final bg=_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white);
    final txt=_isEditorial?Editorial.ink:(_isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    final div=_isEditorial?Editorial.divider:(_isDark?DarkPremium.divider:GoogleColors.divider);
    final accent=_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.blue);
    showModalBottomSheet(context:context, backgroundColor:bg, shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))), builder:(ctx){
      return StatefulBuilder(builder:(ctx,setS)=> Padding(padding:const EdgeInsets.fromLTRB(20,12,20,20), child:Column(mainAxisSize:MainAxisSize.min, crossAxisAlignment:CrossAxisAlignment.start, children:[
        Center(child:Container(width:32,height:4, decoration:BoxDecoration(color:div, borderRadius:BorderRadius.circular(2)))), const SizedBox(height:16),
        Text('Walk options', style:TextStyle(fontWeight:FontWeight.w800, fontSize:16, color:txt, fontFamily:'serif')), const SizedBox(height:16),
        _settingRow('Avoid stairs', _avoidStairs, (v)=> setState(()=>_avoidStairs=v)),
        const SizedBox(height:10),
        Row(children:[Icon(Icons.speed, size:18, color:sub), const SizedBox(width:8), Text('Pace: ${_walkingSpeed.toStringAsFixed(1)} km/h', style:TextStyle(fontSize:13, color:txt, fontStyle:FontStyle.italic))]),
        Slider(value:_walkingSpeed, min:1,max:8, divisions:14, activeColor:accent, inactiveColor:div, label:'${_walkingSpeed.toStringAsFixed(1)} km/h', onChanged:(v){ setState(()=>_walkingSpeed=v); setS((){}); }),
        Divider(color:div),
        ListTile(leading:Icon(Icons.terrain, color:sub), title:Text('Costing', style:TextStyle(fontSize:14, color:txt)), trailing:DropdownButton<String>(value:_costing, dropdownColor:bg, underline:const SizedBox(), style:TextStyle(color:txt), items:const[DropdownMenuItem(value:'pedestrian', child:Text('Wander')),DropdownMenuItem(value:'campus_pedestrian', child:Text('Campus')),DropdownMenuItem(value:'auto', child:Text('Drive')),DropdownMenuItem(value:'bicycle', child:Text('Cycle'))], onChanged:(v){ if(v!=null) setState(()=>_costing=v); Navigator.pop(ctx); if(_routeLatLngs!=null) _fetchRoute(); })),
        if(_routeLatLngs!=null) SizedBox(width:double.infinity, child:FilmedButton(icon:const Icon(Icons.refresh, size:18), label:const Text('Re-draw route'), onPressed:(){ Navigator.pop(ctx); _fetchRoute(); }, isDark:_isDark, isEditorial:_isEditorial)),
      ])));
    });
  }
  Widget _settingRow(String label, bool val, ValueChanged<bool> onChanged){
    final bg=_isEditorial?Editorial.paperDark:(_isDark?DarkPremium.cardElevated:GoogleColors.surface);
    final border=_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border);
    final txt=_isEditorial?Editorial.ink:(_isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    final accent=_isEditorial?Editorial.coral:(_isDark?DarkPremium.neonBlue:GoogleColors.blue);
    return Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6), decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(12), border:Border.all(color:border)), child:Row(children:[Icon(Icons.stairs, size:18, color:sub), const SizedBox(width:8), Text(label, style:TextStyle(fontSize:14, color:txt, fontStyle:FontStyle.italic)), const Spacer(), Switch(value:val, onChanged:onChanged, activeThumbColor:accent)]));
  }
  Widget _buildNav(){
    return Scaffold(backgroundColor:_isEditorial?Editorial.paper:(_isDark?DarkPremium.bg:GoogleColors.surface), body:Stack(children:[
      _buildMap(), if(_navUpdate!=null) Positioned(top:0,left:0,right:0, child:NavigationBanner(update:_navUpdate!, onExit:_exitNavigation, isDark:_isDark, isEditorial:_isEditorial)),
      Positioned(right:8, bottom:MediaQuery.of(context).padding.bottom+32, child:_buildRightControls()),
      if(_navUpdate?.arrived==true) Positioned(bottom:MediaQuery.of(context).padding.bottom+24, left:24,right:24, child:FilmedButton(icon:const Icon(Icons.check), label:const Text('Arrived'), onPressed:_exitNavigation, isDark:_isDark, isEditorial:_isEditorial)),
    ]));
  }
  Widget _buildRecord(){
    return Scaffold(backgroundColor:_isEditorial?Editorial.paper:(_isDark?DarkPremium.bg:GoogleColors.surface), body:Stack(children:[
      _buildMap(),
      Positioned(top:MediaQuery.of(context).padding.top+8, left:8,right:8, child:Material(elevation:4, borderRadius:BorderRadius.circular(24), child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8), decoration:BoxDecoration(color:_isEditorial?Editorial.card:(_isDark?DarkPremium.card:Colors.white), borderRadius:BorderRadius.circular(24), border:Border.all(color:_isEditorial?Editorial.border:(_isDark?DarkPremium.border:GoogleColors.border))), child:Row(children:[Container(width:8,height:8, decoration:BoxDecoration(color:_isEditorial?Editorial.coral:GoogleColors.red, shape:BoxShape.circle)), const SizedBox(width:6), Text(_recordingService.isPaused?'Paused':'Recording — ${_isEditorial?'editorial':(_isDark?'dark':'light')}', style:TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:_recordingService.isPaused?(_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary)):(_isEditorial?Editorial.coral:GoogleColors.red), fontStyle:FontStyle.italic)), const Spacer(), IconButton(icon:Icon(Icons.close, size:20, color:_isEditorial?Editorial.inkSecondary:(_isDark?DarkPremium.textSecondary:GoogleColors.textSecondary)), onPressed:_stopRecording)])))),
      if(_recordingStats!=null) Positioned(top:MediaQuery.of(context).padding.top+64, left:0,right:0, child:RecordingStatsCard(stats:_recordingStats!, isDark:_isDark, isEditorial:_isEditorial)),
      Positioned(bottom:0,left:0,right:0, child:RecordingControls(state:_recordingService.state, onStart:_startRecording, onPause:_pauseRecording, onResume:_resumeRecording, onStop:_stopRecording, isDark:_isDark, isEditorial:_isEditorial)),
    ]));
  }
  void _onMapEvent(MapEvent e){ if(e is MapEventRotate) setState(()=> _rotation=e.camera.rotation%360); }
  Widget _buildMap(){
    String url; List<String> sub=[];
    if(_mapStyle==MapStyle.satellite) url='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    else if(_mapStyle==MapStyle.dark){ url='https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'; sub=['a','b','c','d']; }
    else if(_mapStyle==MapStyle.editorial){ url='https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'; sub=['a','b','c','d']; }
    else url='https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final routeColor=_isEditorial?Editorial.route:(_isDark?DarkPremium.route:GoogleColors.blue);
    final outlineColor=_isEditorial?Editorial.routeOutline:(_isDark?DarkPremium.routeOutline:Colors.white);
    final trailColor=_isEditorial?Editorial.terracotta:(_isDark?DarkPremium.neonGreen:GoogleColors.red);
    final campusPoly=[const LatLng(6.511,3.347), const LatLng(6.511,3.355), const LatLng(6.519,3.355), const LatLng(6.519,3.347)];
    Color wash, borderC;
    if(_isEditorial){ wash=Editorial.campusWash; borderC=Editorial.campusBorder; } else if(_isDark){ wash=DarkPremium.neonBlue.withAlpha(10); borderC=DarkPremium.neonBlue.withAlpha(35); } else { wash=Colors.transparent; borderC=Colors.transparent; }
    return FlutterMap(
      mapController:_mapController,
      options:MapOptions(initialCenter:_medilagCenter, initialZoom:16, onTap:_mode==MapMode.explore?_onMapTap:null, onMapEvent:_onMapEvent),
      children:[
        TileLayer(urlTemplate:url, subdomains:sub, userAgentPackageName:'com.runit.maps'),
        if(_routeLatLngs!=null) ...[
          PolylineLayer(polylines:[Polyline(points:_routeLatLngs!, color: _isEditorial? Editorial.routeGlow: (_isDark? DarkPremium.routeGlow: outlineColor.withAlpha(180)), strokeWidth:_isEditorial?12:(_isDark?14:9))]),
          PolylineLayer(polylines:[Polyline(points:_routeLatLngs!, color:outlineColor, strokeWidth:_isEditorial?7:(_isDark?8:7))]),
          PolylineLayer(polylines:[Polyline(points:_routeLatLngs!, color:routeColor, strokeWidth:_isEditorial?4:(_isDark?4:5))]),
        ],
        if(_recordingTrail.length>=2) PolylineLayer(polylines:[Polyline(points:_recordingTrail, color:trailColor, strokeWidth:4)]),
        if(_isEditorial||_isDark) PolygonLayer(polygons:[Polygon(points:campusPoly, color:wash, borderColor:borderC, borderStrokeWidth:1.2, isFilled:true, label: _isEditorial?'MEDILAG':null, labelStyle:TextStyle(fontSize:10, fontWeight:FontWeight.w800, color:borderC))]),
        MarkerLayer(markers:[
          if(_mode==MapMode.explore) ...[
            if(_origin!=null) Marker(point:_origin!, width:42,height:48, child:_editorialPin(isOrigin:true)),
            if(_destination!=null) Marker(point:_destination!, width:42,height:48, child:_editorialPin(isOrigin:false)),
          ],
          if(_selectedStep!=null) Marker(point:LatLng(_selectedStep!.lat,_selectedStep!.lng), width:42,height:42, child:_streetPin(_selectedStep!.isCustomPath)),
          if(_currentLocation!=null) Marker(point:_currentLocation!, width:52,height:52, alignment:Alignment.center, child:UserLocationMarker(heading:_currentHeading, isNavigating:_mode==MapMode.navigate, isDark:_isDark, isEditorial:_isEditorial)),
        ]),
      ],
    );
  }
  Widget _editorialPin({required bool isOrigin}){
    if(_isEditorial){
      final bg=isOrigin?Editorial.pinOrigin:Editorial.pinDest;
      final letter=isOrigin?'A':'B';
      return Column(mainAxisSize:MainAxisSize.min, children:[
        Container(width:38,height:38, decoration:BoxDecoration(color:bg, shape:BoxShape.circle, border:Border.all(color:Editorial.card, width:2.5), boxShadow:[BoxShadow(color:bg.withAlpha(60), blurRadius:10), BoxShadow(color:Colors.black.withAlpha(25), blurRadius:6)]), child:Center(child:Text(letter, style:const TextStyle(color:Colors.white, fontWeight:FontWeight.w900, fontSize:14, fontFamily:'serif')))),
        Transform.translate(offset:const Offset(0,-7), child:CustomPaint(size:const Size(12,8), painter:_PinPainter(bg))),
      ]);
    }
    final color=isOrigin?(_isDark?DarkPremium.pinOrigin:GoogleColors.green):(_isDark?DarkPremium.pinDest:GoogleColors.red);
    return Column(mainAxisSize:MainAxisSize.min, children:[
      Container(width:36,height:36, decoration:BoxDecoration(color:color, shape:BoxShape.circle, border:Border.all(color:_isDark?DarkPremium.bg:Colors.white, width:2.5), boxShadow:[BoxShadow(color:color.withAlpha(90), blurRadius:10), BoxShadow(color:Colors.black.withAlpha(60), blurRadius:6)]), child:Center(child:Text(isOrigin?'A':'B', style:TextStyle(color:_isDark?DarkPremium.bg:Colors.white, fontWeight:FontWeight.w900, fontSize:14)))),
      Transform.translate(offset:const Offset(0,-6), child:CustomPaint(size:const Size(14,10), painter:_PinPainter(color))),
    ]);
  }
  Widget _streetPin(bool isCampus){
    final c=isCampus?(_isEditorial?Editorial.mustard:DarkPremium.neonYellow):(_isEditorial?Editorial.coral:DarkPremium.neonBlue);
    final bg=isCampus?(_isEditorial?Editorial.card:DarkPremium.bg):(_isEditorial?Editorial.card:DarkPremium.bg);
    return Container(width:36,height:36, decoration:BoxDecoration(color:c, shape:BoxShape.circle, border:Border.all(color:Colors.white, width:2.5), boxShadow:[BoxShadow(color:c.withAlpha(70), blurRadius:10)]), child:Icon(isCampus?Icons.school:Icons.streetview, color:isCampus?Editorial.navy:Colors.white, size:18));
  }
  void _showGps(){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enable location to wander'), backgroundColor:Color(0xFF323232))); }
  @override void dispose(){ _posSub?.cancel(); _headingSub?.cancel(); _navSub?.cancel(); _recStateSub?.cancel(); _recStatsSub?.cancel(); _locationService.dispose(); _navigationService?.dispose(); _recordingService.dispose(); super.dispose(); }
}
class FilmedStyle {
  static ButtonStyle call({bool isDark=false, bool isEditorial=false}){
    final bg=isEditorial?Editorial.coral:(isDark?DarkPremium.neonBlue:GoogleColors.blue);
    final fg=isEditorial||isDark?Colors.white:Colors.white;
    return FilledButton.styleFrom(backgroundColor:bg, foregroundColor:fg, padding:const EdgeInsets.symmetric(vertical:12), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)));
  }
}
class FilmedButton extends StatelessWidget {
  final Widget icon; final Widget label; final VoidCallback? onPressed; final bool isDark; final bool isEditorial;
  const FilmedButton({super.key, required this.icon, required this.label, this.onPressed, this.isDark=false, this.isEditorial=false});
  @override Widget build(BuildContext context){ return FilledButton.icon(onPressed:onPressed, icon:icon, label:label, style:FilmedStyle.call(isDark:isDark, isEditorial:isEditorial)); }
}
class _PinPainter extends CustomPainter { final Color color; _PinPainter(this.color); @override void paint(Canvas canvas, Size size){ final p=Paint()..color=color; final path=ui.Path()..moveTo(size.width/2,size.height)..lineTo(0,0)..lineTo(size.width,0)..close(); canvas.drawPath(path,p); } @override bool shouldRepaint(covariant CustomPainter o)=>false; }
