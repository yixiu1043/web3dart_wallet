import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:sp_util/sp_util.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'dart:math' as math;

// const String apiUrl = 'http://localhost:7545';
const String API_URL =
    'https://eth-sepolia.g.alchemy.com/v2/yhAmHr1Wks6n565P1FUhNcHnNx9qstYx';

const String WALLET_PATH = "m/44'/60'/0'/0/0"; // 钱包的派生路径
const String WALLET_PATH2 = "m/44'/60'/0'/0/1"; // 钱包的派生路径
const String WALLET_PATH3 = "m/44'/60'/0'/0/1"; // 钱包的派生路径

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SpUtil.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> _mnemonic = [];
  final String _passphrase = '';
  String _balance = '';
  String _address = '';

  late wallet.PrivateKey _privateKey;
  late Web3Client _web3Client;

  @override
  void initState() {
    _setupWallet();
    super.initState();
  }

  void _setupWallet() async {
    final localPrivateKey = SpUtil.getString("private_key");

    late wallet.PrivateKey privateKey;
    if (localPrivateKey == null || localPrivateKey.isEmpty) {
      final mnemonic = _getMnemonic();
      privateKey = _getPrivateKey(mnemonic, _passphrase);
      setState(() {
        _mnemonic = mnemonic;
      });
    } else {
      privateKey = wallet.PrivateKey(BigInt.parse(localPrivateKey));
    }

    final publicKey = _getPublicKey(privateKey);
    final address = _getWalletAddress(publicKey);
    final web3Client = _getWeb3Client(privateKey, API_URL);

    _privateKey = privateKey;
    SpUtil.putString("private_key", privateKey.value.toString());
    setState(() {
      _address = address;
    });
    _web3Client = web3Client;

    final balance = await _getBalance(address);

    setState(() {
      _balance = balance;
    });

    if (kDebugMode) {
      print('你的私钥：${bytesToHex(intToBytes(privateKey.value))}');
      print('你的钱包地址：$_address');
    }
  }

  /// 生成助记词
  List<String> _getMnemonic() {
    return wallet.generateMnemonic();
  }

  /// 生成私钥
  wallet.PrivateKey _getPrivateKey(
    List<String> mnemonic,
    String passphrase,
  ) {
    final seed = wallet.mnemonicToSeed(mnemonic, passphrase: passphrase);
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.tprv);
    final root = master.forPath(WALLET_PATH);

    return wallet.PrivateKey((root as wallet.ExtendedPrivateKey).key);
  }

  /// 生成公钥
  wallet.PublicKey _getPublicKey(wallet.PrivateKey privateKey) {
    return wallet.ethereum.createPublicKey(privateKey);
  }

  String _getWalletAddress(wallet.PublicKey publicKey) {
    return wallet.ethereum.createAddress(publicKey);
  }

  /// 生成钱包地址
  Web3Client _getWeb3Client(wallet.PrivateKey privateKey, String apiUrl) {
    return Web3Client(apiUrl, Client());
  }

  Future<String> _getBalance(String address) async {
    final balance =
        await _web3Client.getBalance(EthereumAddress.fromHex(address));
    final ether = balance.getValueInUnit(EtherUnit.ether);

    return ether.toStringAsFixed(5);
  }

  void _sendTransaction() async {
    final chainId = await _web3Client.getChainId();
    const toAddress = '0x68037B698433Cf1C47645c08db18aB03538F6fd1'; // 转出地址

    const amountInEth = 0.01; // 0.01ETH
    final amountInWei = EtherAmount.fromUnitAndValue(
      EtherUnit.wei,
      BigInt.from(amountInEth * math.pow(10, 18)),
    );
    await _web3Client.sendTransaction(
      EthPrivateKey.fromInt(_privateKey.value),
      Transaction(
        to: EthereumAddress.fromHex(toAddress),
        value: amountInWei,
        // value: EtherAmount.get(EtherUnit.ether, 0.01),
      ),
      chainId: chainId.toInt(),
    );
    showAlertDialog();
    _refreshBalance();
  }

  void _refreshBalance() async {
    final balance = await _getBalance(_address);
    setState(() {
      _balance = balance;
    });
  }

  void showAlertDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          //可滑动
          content: const Text('成功！'),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Column(
              children: [
                Text(
                  '你的助记词：',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Wrap(
                  spacing: 20,
                  children: [
                    for (int i = 0; i < _mnemonic.length; i++)
                      Text(
                        '${_mnemonic[i]} ',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                  ],
                ),
                Text(
                  '你的私钥：${bytesToHex(intToBytes(_privateKey.value))}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '你的公钥：${bytesToHex(_getPublicKey(_privateKey).value)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '你的钱包地址：$_address',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '当前余额：$_balance',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: _refreshBalance,
                  child: const Text('获取余额'),
                ),
                ElevatedButton(
                  onPressed: _sendTransaction,
                  child: const Text('转出'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
