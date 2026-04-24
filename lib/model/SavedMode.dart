import 'package:zoltraak_app/model/RoadParams.dart';

class SavedMode {
  final int? id;
  final String name;
  final RoadParams params;
  final double roadWidth;
  final double speed;
  final int repetitions;

  const SavedMode({
    this.id,
    required this.name,
    required this.params,
    this.roadWidth = 80,
    this.speed = 150,
    this.repetitions = 3,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'peak_height_factor': params.peakHeightFactor,
        'slope_up_width_factor': params.slopeUpWidthFactor,
        'slope_down_width_factor': params.slopeDownWidthFactor,
        'top_flat_factor': params.topFlatFactor,
        'bottom_flat_factor': params.bottomFlatFactor,
        'baseline_y_factor': params.baselineYFactor,
        'road_width': roadWidth,
        'speed': speed,
        'repetitions': repetitions,
      };

  factory SavedMode.fromMap(Map<String, dynamic> map) => SavedMode(
        id: map['id'] as int?,
        name: map['name'] as String,
        params: RoadParams(
          peakHeightFactor: (map['peak_height_factor'] as num).toDouble(),
          slopeUpWidthFactor: (map['slope_up_width_factor'] as num).toDouble(),
          slopeDownWidthFactor:
              (map['slope_down_width_factor'] as num).toDouble(),
          topFlatFactor: (map['top_flat_factor'] as num).toDouble(),
          bottomFlatFactor: (map['bottom_flat_factor'] as num).toDouble(),
          baselineYFactor: (map['baseline_y_factor'] as num).toDouble(),
        ),
        roadWidth: (map['road_width'] as num).toDouble(),
        speed: (map['speed'] as num).toDouble(),
        repetitions: map['repetitions'] as int,
      );

  SavedMode copyWith({
    int? id,
    String? name,
    RoadParams? params,
    double? roadWidth,
    double? speed,
    int? repetitions,
  }) =>
      SavedMode(
        id: id ?? this.id,
        name: name ?? this.name,
        params: params ?? this.params,
        roadWidth: roadWidth ?? this.roadWidth,
        speed: speed ?? this.speed,
        repetitions: repetitions ?? this.repetitions,
      );
}
