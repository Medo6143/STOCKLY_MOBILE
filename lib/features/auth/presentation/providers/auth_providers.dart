import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stockly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';
import 'package:stockly/features/auth/domain/usecases/login_use_case.dart';
import 'package:stockly/features/auth/domain/usecases/logout_use_case.dart';
import 'package:stockly/features/auth/domain/usecases/register_use_case.dart';
import 'package:stockly/features/auth/domain/usecases/restore_session_use_case.dart';

// Composition root of the auth feature: the only presentation file that
// imports the data layer (design §1.1).

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  ),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(ref.watch(authRepositoryProvider)),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final restoreSessionUseCaseProvider = Provider<RestoreSessionUseCase>(
  (ref) => RestoreSessionUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);
