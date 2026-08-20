import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // SOSTITUISCI QUESTA STRINGA CON LA TUA CHIAVE REALE DI GEMINI
  final String _geminiApiKey =AQ.Ab8RN6KT-mwqeTbPMvuhLUBkJjMe-Jlc2OrK7DFLzyVVsGny1Q;
  
  bool _isLoading = false;
  String _statoAnalisi = '';
  
  int _kmSelezionati = 4;
  bool _conCani = false;
  bool _conBambini = false;

  Future<void> _avviaAnalisiZona() async {
    setState(() {
      _isLoading = true;
      _statoAnalisi = 'Rilevamento GPS...';
    });

    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        _statoAnalisi = 'Scansione 10 km con Gemini...';
      });

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
      final prompt = '''
      Posizione GPS utente: Lat ${pos.latitude}, Lon ${pos.longitude}.
      Analizza la zona montana nel raggio di 10 km da queste coordinate.
      Fai un elenco sintetico dei Punti di Interesse trovati:
      - Parcheggi principali
      - Fontane / Punti acqua
      - Rifugi / Punti ristoro
      - Sentieri principali e punti panoramici
      ''';

      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        _isLoading = false;
      });

      _mostraDialogRisultati(
        titolo: 'Panoramica Zona (10 km)',
        testo: response.text ?? 'Nessun dato trovato.',
        mostraFiltri: true,
        pos: pos,
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la scansione: $e')),
      );
    }
  }

  Future<void> _generaPercorsoSuMisura(Position pos) async {
    setState(() {
      _isLoading = true;
      _statoAnalisi = 'Creazione del sentiero su misura...';
    });

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
      final prompt = '''
      Crea un percorso escursionistico partendo dalle coordinate: Lat ${pos.latitude}, Lon ${pos.longitude}.
      Parametri utente:
      - Distanza desiderata: circa $_kmSelezionati km
      - Adatto a cani: ${_conCani ? "SÌ (evita zone esposte/ferrate)" : "NO"}
      - Adatto a bambini: ${_conBambini ? "SÌ (basso dislivello)" : "NO"}

      Fornisci una descrizione dettagliata del percorso, compresi il tempo di percorrenza stimato e il dislivello.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        _isLoading = false;
      });

      _mostraDialogRisultati(
        titolo: 'Percorso Consigliato ($_kmSelezionati km)',
        testo: response.text ?? 'Impossibile generare il percorso.',
        mostraFiltri: false,
        pos: pos,
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _mostraDialogRisultati({
    required String titolo, 
    required String testo, 
    required bool mostraFiltri,
    required Position pos
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titolo, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 10),
                    Text(testo, style: Theme.of(context).textTheme.bodyLarge),
                    const Divider(height: 30),
                    
                    if (mostraFiltri) ...[
                      Text("Personalizza la tua camminata:", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      
                      Row(
                        children: [2, 4, 6].map((km) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text('$km km'),
                              selected: _kmSelezionati == km,
                              onSelected: (selected) {
                                setModalState(() => _kmSelezionati = km);
                                setState(() => _kmSelezionati = km);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      
                      CheckboxListTile(
                        title: const Text("Insieme a cani"),
                        value: _conCani,
                        onChanged: (val) {
                          setModalState(() => _conCani = val ?? false);
                          setState(() => _conCani = val ?? false);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("Adatto a bambini"),
                        value: _conBambini,
                        onChanged: (val) {
                          setModalState(() => _conBambini = val ?? false);
                          setState(() => _conBambini = val ?? false);
                        },
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.directions_walk),
                        label: const Text("Crea Sentiero Perfetto"),
                        onPressed: () {
                          Navigator.pop(context);
                          _generaPercorsoSuMisura(pos);
                        },
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoTr-AI'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  'v10.1',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 15),
                  Text(_statoAnalisi, style: Theme.of(context).textTheme.bodyLarge),
                ],
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.my_location, size: 28),
                label: const Text('INIZIA (Scansiona 10 km)', style: TextStyle(fontSize: 18)),
                onPressed: _avviaAnalisiZona,
              ),
      ),
    );
  }
}
