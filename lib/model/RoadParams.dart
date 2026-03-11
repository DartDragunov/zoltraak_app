class RoadParams {
  /// Y do pico como fração de maxHeight (menor = mais alto na tela).
  final double peakHeightFactor;

  /// Largura da rampa de SUBIDA como fração de maxWidth.
  /// Valor menor = subida mais íngreme.
  final double slopeUpWidthFactor;

  /// Largura da rampa de DESCIDA como fração de maxWidth.
  /// Valor menor = descida mais íngreme.
  final double slopeDownWidthFactor;

  /// Trecho plano no TOPO entre subida e descida (fração de maxWidth).
  final double topFlatFactor;

  /// Trecho plano embaixo entre descida e próxima subida (fração de maxWidth).
  final double bottomFlatFactor;

  /// Y da linha de base (parte plana) como fração da altura do widget.
  /// 0.8 = 80% para baixo → estrada inicia próxima à base.
  final double baselineYFactor;

  const RoadParams({
    this.peakHeightFactor = 0.15,
    this.slopeUpWidthFactor = 0.18,
    this.slopeDownWidthFactor = 0.18,
    this.topFlatFactor = 0.15,
    this.bottomFlatFactor = 0.20,
    this.baselineYFactor = 0.80,
  });

  RoadParams copyWith({
    double? peakHeightFactor,
    double? slopeUpWidthFactor,
    double? slopeDownWidthFactor,
    double? topFlatFactor,
    double? bottomFlatFactor,
    double? baselineYFactor,
  }) =>
      RoadParams(
        peakHeightFactor: peakHeightFactor ?? this.peakHeightFactor,
        slopeUpWidthFactor: slopeUpWidthFactor ?? this.slopeUpWidthFactor,
        slopeDownWidthFactor: slopeDownWidthFactor ?? this.slopeDownWidthFactor,
        topFlatFactor: topFlatFactor ?? this.topFlatFactor,
        bottomFlatFactor: bottomFlatFactor ?? this.bottomFlatFactor,
        baselineYFactor: baselineYFactor ?? this.baselineYFactor,
      );
}
