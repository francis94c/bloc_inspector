import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_investigator_client/client/flutter_bloc_investigator_client.dart';

class InvestigativeBlocObserver extends BlocObserver {
  final FlutterBlocInvestigatorClient client;

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

  // @override
  // void onChange(BlocBase bloc, Change change) {
  //   super.onChange(bloc, change);
  //   client.onBlocChange(bloc, change);
  // }

  // @override
  // void onEvent(Bloc bloc, Object? event) {
  //   super.onEvent(bloc, event);
  // }

  // @override
  // void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
  //   client.onBlocError();
  //   super.onError(bloc, error, stackTrace);
  // }

  // @override
  // void onClose(BlocBase bloc) {
  //   super.onClose(bloc);
  // }
}
