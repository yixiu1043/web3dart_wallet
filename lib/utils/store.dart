import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart';

class Store {
  static String walletAddress = "";
  static late wallet.PrivateKey privateKey;
  static late Web3Client web3Client;
}