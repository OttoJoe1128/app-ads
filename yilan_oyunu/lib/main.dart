import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int kIzgaraGenislik = 20;
const int kIzgaraYukseklik = 28;
const int kBaslangicUzunluk = 4;
const int kTickMs = 120;
const double kMinPan = 6;
const Color kZeminRenk = Color(0xFF101418);
const Color kYilanRenk = Color(0xFF4CAF50);
const Color kKafasiRenk = Color(0xFF66BB6A);
const Color kYemRenk = Color(0xFFE53935);

enum Yon { yukari, asagi, sol, sag }

@immutable
class Konum {
  final int x;
  final int y;
  const Konum({required this.x, required this.y});
  Konum ileri(Yon yon) {
    switch (yon) {
      case Yon.yukari:
        return Konum(x: x, y: y - 1);
      case Yon.asagi:
        return Konum(x: x, y: y + 1);
      case Yon.sol:
        return Konum(x: x - 1, y: y);
      case Yon.sag:
        return Konum(x: x + 1, y: y);
    }
  }
  bool koseDisiMi(int genislik, int yukseklik) => x < 0 || y < 0 || x >= genislik || y >= yukseklik;
  @override
  bool operator ==(Object other) => other is Konum && x == other.x && y == other.y;
  @override
  int get hashCode => Object.hash(x, y);
}

@immutable
class OyunDurumu {
  final List<Konum> yilan;
  final Konum yem;
  final Yon yon;
  final bool oyunBitti;
  final bool calisiyor;
  final int skor;
  const OyunDurumu({
    required this.yilan,
    required this.yem,
    required this.yon,
    required this.oyunBitti,
    required this.calisiyor,
    required this.skor,
  });
  OyunDurumu copyWith({
    List<Konum>? yilan,
    Konum? yem,
    Yon? yon,
    bool? oyunBitti,
    bool? calisiyor,
    int? skor,
  }) {
    return OyunDurumu(
      yilan: yilan ?? this.yilan,
      yem: yem ?? this.yem,
      yon: yon ?? this.yon,
      oyunBitti: oyunBitti ?? this.oyunBitti,
      calisiyor: calisiyor ?? this.calisiyor,
      skor: skor ?? this.skor,
    );
  }
}

final NotifierProvider<OyunDenetleyici, OyunDurumu> oyunDenetleyiciProvider =
    NotifierProvider<OyunDenetleyici, OyunDurumu>(OyunDenetleyici.new);

class OyunDenetleyici extends Notifier<OyunDurumu> {
  final Random rastgele = Random();
  Timer? zamanlayici;
  @override
  OyunDurumu build() {
    ref.onDispose(() {
      zamanlayici?.cancel();
    });
    return _baslangicDurumu();
  }
  static OyunDurumu _baslangicDurumu() {
    final int merkezX = kIzgaraGenislik ~/ 2;
    final int merkezY = kIzgaraYukseklik ~/ 2;
    final List<Konum> baslangicYilan = List<Konum>.generate(
      kBaslangicUzunluk,
      (int i) => Konum(x: merkezX - kBaslangicUzunluk + 1 + i, y: merkezY),
    );
    return OyunDurumu(
      yilan: baslangicYilan,
      yem: Konum(x: 1, y: 1),
      yon: Yon.sag,
      oyunBitti: false,
      calisiyor: false,
      skor: 0,
    );
  }
  void oyunuBaslat() {
    if (state.calisiyor) return;
    if (state.oyunBitti) state = _baslangicDurumu();
    if (state.yilan.contains(state.yem)) _yemiYenile();
    _zamanlayiciyiBaslat();
    state = state.copyWith(calisiyor: true);
  }
  void oyunuDuraklat() {
    if (!state.calisiyor) return;
    zamanlayici?.cancel();
    state = state.copyWith(calisiyor: false);
  }
  void oyunuYenidenBaslat() {
    zamanlayici?.cancel();
    state = _baslangicDurumu();
    _yemiYenile();
    _zamanlayiciyiBaslat();
    state = state.copyWith(calisiyor: true);
  }
  void yonuAyarla(Yon yeniYon) {
    final Yon mevcut = state.yon;
    if (!_yonDegisimiGecerliMi(mevcut, yeniYon)) return;
    state = state.copyWith(yon: yeniYon);
  }
  void _zamanlayiciyiBaslat() {
    zamanlayici?.cancel();
    zamanlayici = Timer.periodic(const Duration(milliseconds: kTickMs), (_) => _adimAt());
  }
  void _adimAt() {
    if (state.oyunBitti) {
      zamanlayici?.cancel();
      return;
    }
    final Konum bas = state.yilan.last;
    final Konum yeniBas = bas.ileri(state.yon);
    if (yeniBas.koseDisiMi(kIzgaraGenislik, kIzgaraYukseklik)) {
      _oyunuBitir();
      return;
    }
    if (state.yilan.contains(yeniBas)) {
      _oyunuBitir();
      return;
    }
    final bool yemYedi = yeniBas == state.yem;
    final List<Konum> yeniGovde = List<Konum>.from(state.yilan)..add(yeniBas);
    if (!yemYedi) yeniGovde.removeAt(0);
    Konum yeniYem = state.yem;
    int yeniSkor = state.skor;
    if (yemYedi) {
      yeniSkor = state.skor + 1;
      yeniYem = _bosKonumUret(yeniGovde);
    }
    state = state.copyWith(yilan: yeniGovde, yem: yeniYem, skor: yeniSkor);
  }
  void _oyunuBitir() {
    zamanlayici?.cancel();
    state = state.copyWith(oyunBitti: true, calisiyor: false);
  }
  void _yemiYenile() {
    final Konum k = _bosKonumUret(state.yilan);
    state = state.copyWith(yem: k);
  }
  Konum _bosKonumUret(List<Konum> dolu) {
    final Set<Konum> doluKumesi = dolu.toSet();
    final int toplam = kIzgaraGenislik * kIzgaraYukseklik;
    if (doluKumesi.length >= toplam) return const Konum(x: 0, y: 0);
    while (true) {
      final int x = rastgele.nextInt(kIzgaraGenislik);
      final int y = rastgele.nextInt(kIzgaraYukseklik);
      final Konum k = Konum(x: x, y: y);
      if (!doluKumesi.contains(k)) return k;
    }
  }
  bool _yonDegisimiGecerliMi(Yon mevcut, Yon yeni) {
    if (mevcut == Yon.yukari && yeni == Yon.asagi) return false;
    if (mevcut == Yon.asagi && yeni == Yon.yukari) return false;
    if (mevcut == Yon.sol && yeni == Yon.sag) return false;
    if (mevcut == Yon.sag && yeni == Yon.sol) return false;
    return mevcut != yeni;
  }
  // Notifier yaşam döngüsü ref.onDispose ile yönetiliyor
}

void main() => runApp(const ProviderScope(child: Uygulama()));

class Uygulama extends StatelessWidget {
  const Uygulama({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yılan Oyunu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: kZeminRenk,
      ),
      home: const AnaSayfa(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AnaSayfa extends ConsumerWidget {
  const AnaSayfa({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OyunDurumu durum = ref.watch(oyunDenetleyiciProvider);
    final OyunDenetleyici denetleyici = ref.read(oyunDenetleyiciProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yılan Oyunu', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Skor: ${durum.skor}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: kIzgaraGenislik / kIzgaraYukseklik,
                child: _OyunTahtasi(durum: durum, denetleyici: denetleyici),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: durum.calisiyor ? denetleyici.oyunuDuraklat : denetleyici.oyunuBaslat,
                  child: Text(durum.calisiyor ? 'Duraklat' : 'Başlat'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: denetleyici.oyunuYenidenBaslat,
                  child: const Text('Yeniden'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OyunTahtasi extends StatelessWidget {
  final OyunDurumu durum;
  final OyunDenetleyici denetleyici;
  const _OyunTahtasi({required this.durum, required this.denetleyici});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      final double hucre = c.maxWidth / kIzgaraGenislik;
      return GestureDetector(
        onPanUpdate: (DragUpdateDetails d) {
          final double dx = d.delta.dx;
          final double dy = d.delta.dy;
          if (dx.abs() < kMinPan && dy.abs() < kMinPan) return;
          if (dx.abs() > dy.abs()) {
            denetleyici.yonuAyarla(dx > 0 ? Yon.sag : Yon.sol);
          } else {
            denetleyici.yonuAyarla(dy > 0 ? Yon.asagi : Yon.yukari);
          }
        },
        child: Stack(
          children: [
            Container(color: kZeminRenk),
            ...durum.yilan.map(
              (Konum k) => Positioned(
                left: k.x * hucre,
                top: k.y * hucre,
                width: hucre,
                height: hucre,
                child: Container(
                  decoration: BoxDecoration(
                    color: k == durum.yilan.last ? kKafasiRenk : kYilanRenk,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Positioned(
              left: durum.yem.x * hucre,
              top: durum.yem.y * hucre,
              width: hucre,
              height: hucre,
              child: Container(decoration: const BoxDecoration(color: kYemRenk, shape: BoxShape.circle)),
            ),
            if (durum.oyunBitti)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Oyun Bitti', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Skor: ${durum.skor}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
