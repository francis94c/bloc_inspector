import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_inspector/client/flutter_bloc_investigative_client.dart';

class InvestigativeBlocObserver extends BlocObserver {
  final FlutterBlocInvestigativeClient client;

  InvestigativeBlocObserver(this.client);

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    client.onCreateBloc(bloc);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    client.onTransition(bloc, transition);
  }
}
