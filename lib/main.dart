import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:sp_util/sp_util.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'dart:math' as math;

// const String apiUrl = 'http://localhost:7545';
// const String API_URL = 'https://eth-sepolia.g.alchemy.com/v2/yhAmHr1Wks6n565P1FUhNcHnNx9qstYx';
const String API_URL = 'https://data-seed-prebsc-1-s1.binance.org:8545';

const String WALLET_PATH = "m/44'/60'/0'/0/0"; // 钱包的派生路径

const PancakeFactoryAddress = '0x5160f2454FcF4FC0bA5753dA1692f456fDeA5A59';
const PancakeRouterAddress = '0xC62A941586C0c844c6900b4fA03f69aD4Af198EA';
const WBNBAddress = '0x4a3C7Edf150C5BC09A226c12A950535d0e6ddD36';
const USDTAddress = '0x5Acb27150a396DbC18fDe7e47CE561c144F1E412';
// const ERC20Address = '0x377533D0E68A22CF180205e9c9ed980f74bc5050';
const YXAddress = '0x619F3033dE662e05C6b64aaA20e5230B4bD388d6';
const WalletAddress = '0x622b7352BD13Df3216368e36d421fF9611A1a363';

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

    _getBalance(address);
    _getTokensBalance();

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

  void _getBalance(String address) async {
    final balance =
        await _web3Client.getBalance(EthereumAddress.fromHex(address));
    final ether = balance.getValueInUnit(EtherUnit.ether);

    setState(() {
      _balance = ether.toStringAsFixed(5);
    });
  }

  void _sendTransaction() async {
    final chainId = await _web3Client.getChainId();
    const toAddress = '0x68037B698433Cf1C47645c08db18aB03538F6fd1'; // 转出地址

    const amountInEth = 0.01; // 0.01ETH
    final amountInWei = EtherAmount.fromBigInt(
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
    _getBalance(_address);
  }

  Future<String> _getLocalJson(String jsonName) async {
    final json = await rootBundle.loadString("assets/abi1/$jsonName.json");
    return json;
  }

  void _allowance() async {
    print(BigInt.from(DateTime.now()
        .add(const Duration(minutes: 20))
        .millisecondsSinceEpoch));

    final erc20 = await _getLocalJson('Erc20');
    final usdtContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'usdt'),
      EthereumAddress.fromHex(USDTAddress),
    );
    final wbnbContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'bnb'),
      EthereumAddress.fromHex(WBNBAddress),
    );
    final yxContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'yx'),
      EthereumAddress.fromHex(YXAddress),
    );

    /// 查询授权
    final allowanceUsdt = await _web3Client.call(
      contract: usdtContract,
      function: usdtContract.function('allowance'),
      params: [
        EthereumAddress.fromHex(WalletAddress),
        EthereumAddress.fromHex(PancakeRouterAddress),
      ],
    );
    final allowanceWbnb = await _web3Client.call(
      contract: wbnbContract,
      function: wbnbContract.function('allowance'),
      params: [
        EthereumAddress.fromHex(WalletAddress),
        EthereumAddress.fromHex(PancakeRouterAddress),
      ],
    );
    final allowanceYx = await _web3Client.call(
      contract: yxContract,
      function: yxContract.function('allowance'),
      params: [
        EthereumAddress.fromHex(WalletAddress),
        EthereumAddress.fromHex(PancakeRouterAddress),
      ],
    );
    print('allowanceUsdt: ${allowanceUsdt}');
    print('allowanceWbnb: ${allowanceWbnb}');
    print('allowanceYx: ${allowanceYx}');
  }

  void _approve() async {
    final erc20 = await _getLocalJson('Erc20');
    final usdtContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'usdt'),
      EthereumAddress.fromHex(USDTAddress),
    );
    final wbnbContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'wbnb'),
      EthereumAddress.fromHex(WBNBAddress),
    );
    final yxContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'yx'),
      EthereumAddress.fromHex(YXAddress),
    );

    final chainId = await _web3Client.getChainId();
    final usdtTx = await _web3Client.sendTransaction(
      EthPrivateKey.fromInt(_privateKey.value),
      Transaction.callContract(
        contract: usdtContract,
        function: usdtContract.function('approve'),
        parameters: [
          EthereumAddress.fromHex(PancakeRouterAddress),
          BigInt.from(10).pow(30)
        ],
        value: EtherAmount.fromBigInt(EtherUnit.ether, BigInt.zero),
      ),
      chainId: chainId.toInt(),
    );
    print('Transaction hash: $usdtTx');

    final wbnbTx = await _web3Client.sendTransaction(
      EthPrivateKey.fromInt(_privateKey.value),
      Transaction.callContract(
        contract: wbnbContract,
        function: wbnbContract.function('approve'),
        parameters: [
          EthereumAddress.fromHex(PancakeRouterAddress),
          BigInt.from(10).pow(30)
        ],
        value: EtherAmount.fromBigInt(EtherUnit.ether, BigInt.zero),
      ),
      chainId: chainId.toInt(),
    );
    print('Transaction hash: $wbnbTx');
    final yxTx = await _web3Client.sendTransaction(
      EthPrivateKey.fromInt(_privateKey.value),
      Transaction.callContract(
        contract: yxContract,
        function: wbnbContract.function('approve'),
        parameters: [
          EthereumAddress.fromHex(PancakeRouterAddress),
          BigInt.from(10).pow(30)
        ],
        value: EtherAmount.fromBigInt(EtherUnit.ether, BigInt.zero),
      ),
      chainId: chainId.toInt(),
    );
    print('Transaction hash: $yxTx');
  }

  void _swapExactETHForTokens() async {
    final chainId = await _web3Client.getChainId();
    final pancakeFactory = await _getLocalJson('PancakeFactory');
    final pancakeRouterAbi = await _getLocalJson('PancakeRouter');

    final pancakeFactoryContract = DeployedContract(
      ContractAbi.fromJson(pancakeFactory, 'PancakeFactory'),
      EthereumAddress.fromHex(PancakeFactoryAddress),
    );
    final pancakeRouterContract = DeployedContract(
      ContractAbi.fromJson(pancakeRouterAbi, 'PancakeRouter'),
      EthereumAddress.fromHex(PancakeRouterAddress),
    );

    /// 获取交易对地址
    // final pairAddress = await _web3Client.call(
    //   contract: pancakeFactoryContract,
    //   function: pancakeFactoryContract.function('getPair'),
    //   params: [
    //     EthereumAddress.fromHex(WBNBAddress),
    //     EthereumAddress.fromHex(USDTAddress),
    //   ],
    // );
    // print('pairAddress: ${pairAddress}');

    /// 获取输出
    // final amountsOut = await _web3Client.call(
    //   contract: pancakeRouterContract,
    //   function: pancakeRouterContract.function('getAmountsOut'),
    //   params: [
    //     BigInt.from(0.001 * math.pow(10, 18)),
    //     [
    //       EthereumAddress.fromHex(WBNBAddress),
    //       EthereumAddress.fromHex(USDTAddress),
    //     ]
    //   ],
    // );
    // print('getAmountsOut: ${amountsOut}');

    final amountIn = EtherAmount.fromBigInt(
      EtherUnit.wei,
      BigInt.from(10).pow(10),
    );
    final amountOutMin = BigInt.zero;

    final tx = await _web3Client.sendTransaction(
      EthPrivateKey.fromInt(_privateKey.value),
      Transaction.callContract(
        contract: pancakeRouterContract,
        function: pancakeRouterContract.function('swapExactETHForTokens'),
        parameters: [
          amountOutMin,
          [
            EthereumAddress.fromHex(WBNBAddress),
            EthereumAddress.fromHex(USDTAddress),
          ],
          EthereumAddress.fromHex(WalletAddress),
          BigInt.from(DateTime.now()
              .add(const Duration(minutes: 20))
              .millisecondsSinceEpoch),
        ],
        value: amountIn,
      ),
      chainId: chainId.toInt(),
    );
    print('Transaction hash: $tx');

    showAlertDialog();
    _getBalance(_address);
  }

  void _swapExactTokensForTokens() async {
    final chainId = await _web3Client.getChainId();
    final pancakeRouter = await _getLocalJson('PancakeRouter');

    final pancakeRouterContract = DeployedContract(
      ContractAbi.fromJson(pancakeRouter, 'PancakeRouter'),
      EthereumAddress.fromHex(PancakeRouterAddress),
    );

    final amountIn = BigInt.from(10).pow(10);

    final tx = await _web3Client.sendTransaction(
      EthPrivateKey.fromInt(_privateKey.value),
      Transaction.callContract(
        contract: pancakeRouterContract,
        function: pancakeRouterContract.function('swapExactTokensForTokens'),
        parameters: [
          amountIn,
          BigInt.zero,
          [
            EthereumAddress.fromHex(USDTAddress),
            EthereumAddress.fromHex(YXAddress),
          ],
          EthereumAddress.fromHex(WalletAddress),
          BigInt.from(DateTime.now()
              .add(const Duration(minutes: 20))
              .millisecondsSinceEpoch),
        ],
      ),
      chainId: chainId.toInt(),
    );

    print('Transaction hash: $tx');
    showAlertDialog();
    _getBalance(_address);
  }

  void _getTokensBalance() async {
    final erc20 = await _getLocalJson('Erc20');
    final usdtContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'usdt'),
      EthereumAddress.fromHex(USDTAddress),
    );
    final yxContract = DeployedContract(
      ContractAbi.fromJson(erc20, 'yx'),
      EthereumAddress.fromHex(YXAddress),
    );
    final usdtBalance = await _web3Client.call(
      contract: usdtContract,
      function: usdtContract.function('balanceOf'),
      params: [EthereumAddress.fromHex(WalletAddress)],
    );
    final yxBalance = await _web3Client.call(
      contract: yxContract,
      function: yxContract.function('balanceOf'),
      params: [EthereumAddress.fromHex(WalletAddress)],
    );

    print('usdtBalance ----- ${usdtBalance[0] / BigInt.from(math.pow(10, 18))}');
    print('usdtBalance ----- ${yxBalance[0] / BigInt.from(math.pow(10, 18))}');
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
                  onPressed: () => _getBalance(_address),
                  child: const Text('获取余额'),
                ),
                ElevatedButton(
                  onPressed: _sendTransaction,
                  child: const Text('转出'),
                ),
                ElevatedButton(
                  onPressed: _allowance,
                  child: const Text('查询授权'),
                ),
                ElevatedButton(
                  onPressed: _approve,
                  child: const Text('授权'),
                ),
                ElevatedButton(
                  onPressed: _swapExactETHForTokens,
                  child: const Text('swapExactETHForTokens'),
                ),
                ElevatedButton(
                  onPressed: _swapExactTokensForTokens,
                  child: const Text('swapExactTokensForTokens'),
                ),
                ElevatedButton(
                  onPressed: _getTokensBalance,
                  child: const Text('获取代币余额'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
