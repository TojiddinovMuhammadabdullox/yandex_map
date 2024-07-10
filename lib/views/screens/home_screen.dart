import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex/service/yandex_service.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late YandexMapController mapController;
  List<MapObject> polylines = [];
  Point? myCurrentLocation;
  Position? _currentLocation;
  LocationPermission? permission;
  final YandexSearch yandexSearch = YandexSearch();
  final TextEditingController _searchTextController = TextEditingController();
  double searchHeight = 250;
  ValueNotifier<bool> nightLight = ValueNotifier(false);

  List<SuggestItem> _suggestionList = [];
  final Point najotTalim = const Point(
    latitude: 41.2856806,
    longitude: 69.2034646,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<SuggestSessionResult> _suggest() async {
    final resultWithSession = await YandexSuggest.getSuggestions(
      text: _searchTextController.text,
      boundingBox: const BoundingBox(
        northEast: Point(latitude: 56.0421, longitude: 38.0284),
        southWest: Point(latitude: 55.5143, longitude: 37.24841),
      ),
      suggestOptions: const SuggestOptions(
        suggestType: SuggestType.geo,
        suggestWords: true,
        userPosition: Point(latitude: 56.0321, longitude: 38),
      ),
    );

    return await resultWithSession.$2;
  }

  Future<void> _showBottomSheet(Point destination) async {
    _currentLocation ??= await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final start = Point(
      latitude: _currentLocation!.latitude,
      longitude: _currentLocation!.longitude,
    );

    final distance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      destination.latitude,
      destination.longitude,
    );

    (distance / 1.4).round();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTransportButton(
                          'Walking', Icons.directions_walk, start, destination),
                      _buildTransportButton(
                          'Cycling', Icons.directions_bike, start, destination),
                      _buildTransportButton(
                          'Driving', Icons.directions_car, start, destination),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransportButton(
      String label, IconData icon, Point start, Point destination) {
    return Column(
      children: [
        FloatingActionButton(
          onPressed: () async {
            Navigator.pop(context);
            polylines = await YandexMapService.getDirection(start, destination,
                mode: label.toLowerCase());
            setState(() {});
          },
          backgroundColor: Colors.grey[700],
          child: Icon(icon, color: Colors.white),
        ),
        const Gap(5),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          YandexMap(
            nightModeEnabled: nightLight.value,
            onMapCreated: (controller) {
              mapController = controller;
              mapController.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: najotTalim,
                    zoom: 17,
                  ),
                ),
              );
              setState(() {});
            },
            onMapLongTap: (point) {
              setState(() {
                _showBottomSheet(point);
                myCurrentLocation = point;
              });
            },
            onCameraPositionChanged: (
              CameraPosition position,
              CameraUpdateReason reason,
              bool finished,
            ) async {
              if (finished && myCurrentLocation != null) {
                polylines = await YandexMapService.getDirection(
                    najotTalim, myCurrentLocation!,
                    mode: '');
                setState(() {});
              }
            },
            mapType: MapType.vector,
            mapObjects: [
              PlacemarkMapObject(
                mapId: const MapObjectId("najotTalim"),
                point: najotTalim,
                opacity: 1,
                icon: PlacemarkIcon.single(
                  PlacemarkIconStyle(
                    scale: nightLight.value ? .4 : .1,
                    image: BitmapDescriptor.fromAssetImage(nightLight.value
                        ? "assets/marker2.png"
                        : "assets/marker.png"),
                  ),
                ),
              ),
              if (myCurrentLocation != null)
                PlacemarkMapObject(
                  opacity: 1,
                  mapId: const MapObjectId("myCurrentLocation"),
                  point: myCurrentLocation!,
                  icon: PlacemarkIcon.single(
                    PlacemarkIconStyle(
                      scale: 0.15,
                      image:
                          BitmapDescriptor.fromAssetImage("assets/marker1.png"),
                    ),
                  ),
                ),
              ...polylines,
            ],
          ),
          Positioned(
            top: 70,
            left: 10,
            right: 10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _suggestionList.isNotEmpty ? searchHeight : 0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.grey[700],
              ),
              child: ListView.builder(
                itemCount: _suggestionList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    onTap: () {
                      setState(() {
                        searchHeight = 0;
                        myCurrentLocation = _suggestionList[index].center;
                      });

                      mapController.moveCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: myCurrentLocation!,
                            zoom: 17,
                          ),
                        ),
                        animation: const MapAnimation(
                          type: MapAnimationType.smooth,
                          duration: 1.5,
                        ),
                      );
                    },
                    title: Text(
                      _suggestionList[index].title,
                      style: const TextStyle(color: Colors.black),
                    ),
                    subtitle: Text(
                      _suggestionList[index].subtitle!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                  ),
                  decoration: InputDecoration(
                    suffixIcon: _suggestionList.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchTextController.text = "";
                                myCurrentLocation = null;
                                polylines = [];
                                _suggestionList = [];
                              });
                            },
                            child: const Icon(CupertinoIcons.clear_fill,
                                color: Colors.grey),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade300,
                    hintText: "Search for a place and address",
                    hintStyle: const TextStyle(
                      color: Colors.black,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  controller: _searchTextController,
                  onChanged: (value) async {
                    final res = await _suggest();
                    if (res.items != null) {
                      setState(() {
                        _suggestionList = res.items!.toSet().toList();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 20,
            left: 15,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    mapController.moveCamera(CameraUpdate.zoomIn());
                  },
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.blue,
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
                const Gap(10),
                GestureDetector(
                  onTap: () {
                    mapController.moveCamera(CameraUpdate.zoomOut());
                  },
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.blue,
                    ),
                    child: const Icon(Icons.remove, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: Colors.blue,
        onPressed: () async {
          _currentLocation = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          final Point currentPoint = Point(
            latitude: _currentLocation!.latitude,
            longitude: _currentLocation!.longitude,
          );
          mapController.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: currentPoint, zoom: 17),
            ),
            animation: const MapAnimation(
              type: MapAnimationType.smooth,
              duration: 1.5,
            ),
          );
        },
        child: const Icon(CupertinoIcons.location, color: Colors.white),
      ),
    );
  }
}
