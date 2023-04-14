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
const String WALLET_PATH2 = "m/44'/60'/0'/0/1"; // 钱包的派生路径
const String WALLET_PATH3 = "m/44'/60'/0'/0/1"; // 钱包的派生路径

const PancakeFactoryAddress = '0x5160f2454FcF4FC0bA5753dA1692f456fDeA5A59';
const PancakeRouterAddress = '0x53968F853bA4413e9EE9ADA14935ee77Fece1027';
const PancakePairAddress = '0x7220599c32a6B6D1D11488CC552f8799E6EcF53E';
const WBNBAddress = '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd';
const USDTAddress = '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd';
const ERC20Address = '0x377533D0E68A22CF180205e9c9ed980f74bc5050';
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
    _getBalance(_address);
  }

  Future<String> _getLocalJson(String jsonName) async {
    final json =
        await rootBundle.loadString("assets/abi1/$jsonName.json");
    return json;
  }

  void _swapExactETHForTokens() async {
    /// TODO
    final chainId = await _web3Client.getChainId();
    final pancakeFactory = await _getLocalJson('PancakeFactory');
    final pancakeRouterAbi = await _getLocalJson('PancakeRouter');
    final pancakePair = await _getLocalJson('PancakePairAddress');

    final pancakeFactoryContract = DeployedContract(
      ContractAbi.fromJson(pancakeFactory, 'PancakeFactory'),
      EthereumAddress.fromHex(PancakeFactoryAddress),
    );
    final pancakeRouterContract = DeployedContract(
      ContractAbi.fromJson(pancakeRouterAbi, 'PancakeRouter'),
      EthereumAddress.fromHex(PancakeRouterAddress),
    );

    final pancakePairContract = DeployedContract(
      ContractAbi.fromJson(pancakePair, 'PancakePair'),
      EthereumAddress.fromHex(PancakePairAddress),
    );

    /// 获取交易对地址
    final pairAddress = await _web3Client.call(
      contract: pancakeFactoryContract,
      function: pancakeFactoryContract.function('getPair'),
      params: [
        EthereumAddress.fromHex(WBNBAddress),
        EthereumAddress.fromHex(USDTAddress),
      ],
    );
    print('pairAddress: ${pairAddress}');

    // /// 获取交易对合约
    // final jackPairContract = DeployedContract(
    //   ContractAbi.fromJson(jackPair, 'jackPair'),
    //   pairAddress[0],
    // );
    //
    // print('pairAddress: ${jackPairContract}');
    //

    /// 获取交易对储备
    // final reserves = await _web3Client.call(
    //   contract: jackPairContract,
    //   function: jackPairContract.function('getReserves'),
    //   params: [],
    // );

    return;
    final amountIn = EtherAmount.fromBigInt(
      EtherUnit.ether,
      BigInt.from(0.01),
    );

    final amountOutMin = BigInt.from(100 * math.pow(10, 18));
    print('amountOutMin: ${amountOutMin}');
    // try {
    //   final tx = await _web3Client.call(
    //     contract: pancakeRouterContract,
    //     function: pancakeRouterContract.function('swapExactETHForTokens'),
    //     params: [
    //       amountOutMin,
    //       [
    //         EthereumAddress.fromHex(
    //             '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'),
    //         EthereumAddress.fromHex(
    //             '0x8f92eB3b8d0D91d4F8924a041Ad94a6b6A67E5e9'),
    //       ],
    //       EthereumAddress.fromHex('0x622b7352BD13Df3216368e36d421fF9611A1a363'),
    //       BigInt.from(DateTime.now()
    //           .add(const Duration(minutes: 20))
    //           .millisecondsSinceEpoch),
    //     ],
    //   );
    //   print('Transaction hash: ${tx[0].hash}');
    //   final swapReceipt = await tx[0].wait();
    //   print('swapReceipt: $swapReceipt');
    // } catch (error, trace) {
    //   print(error);
    //   print(trace);
    // }
    try {
      final tx = await _web3Client.sendTransaction(
        EthPrivateKey.fromInt(_privateKey.value),
        Transaction.callContract(
          contract: pancakeRouterContract,
          function: pancakeRouterContract.function('swapExactETHForTokens'),
          parameters: [
            amountOutMin,
            [
              EthereumAddress.fromHex(
                  '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'),
              EthereumAddress.fromHex(
                  '0x8f92eB3b8d0D91d4F8924a041Ad94a6b6A67E5e9'),
            ],
            EthereumAddress.fromHex(
                '0x622b7352BD13Df3216368e36d421fF9611A1a363'),
            BigInt.from(DateTime.now()
                .add(const Duration(minutes: 20))
                .millisecondsSinceEpoch),
          ],
          value: amountIn,
        ),
        chainId: chainId.toInt(),
      );
      // pairAddress: [0x284a7b83a10b0d91dc64ab04574507294fbf2acd]
      // reserves: [10891949504848443278689669, 745497565636525320, 1680942752]
      //  amountOutMin: 7766279631452241920
      // Transaction hash: 0x55df6b6e7134040721b9e34ae44e12409420e696f89638d5b2ce2c5caba3b1df
      // balance ----- 143984.69095942142
      print('Transaction hash: $tx');
    } catch (error, trace) {
      print(error);
      print(trace);
    }
    showAlertDialog();
    _getBalance(_address);
  }

  void _swapExactTokensForTokens() async {
    /// TODO
    // final chainId = await _web3Client.getChainId();
    final pancakeRouter = await _getLocalJson('PancakeRouter');
    final erc20 = await _getLocalJson('erc20');
    final pancakeFactory = await _getLocalJson('PancakeFactory');
    final jackPair = await _getLocalJson('jackPair');

    final pancakeRouterContract = DeployedContract(
      ContractAbi.fromJson(pancakeRouter, 'PancakeRouter'),
      EthereumAddress.fromHex('0x10ED43C718714eb63d5aA57B78B54704E256024E'),
    );
    final erc20Contract = DeployedContract(
      ContractAbi.fromJson(erc20, 'erc20'),
      EthereumAddress.fromHex('0x8f92eB3b8d0D91d4F8924a041Ad94a6b6A67E5e9'),
    );
    final pancakeFactoryContract = DeployedContract(
      ContractAbi.fromJson(pancakeFactory, 'PancakeFactory'),
      EthereumAddress.fromHex('0x6725f303b657a9451d8ba641348b6761a6cc7a17'),
    );

    /// 查询授权
    final allowanceErc20 = await _web3Client.call(
      contract: erc20Contract,
      function: erc20Contract.function('allowance'),
      params: [
        EthereumAddress.fromHex('0x622b7352BD13Df3216368e36d421fF9611A1a363'),
        EthereumAddress.fromHex('0xd99d1c33f9fc3444f8101754abc46c52416550d1'),
      ],
    );

    print('allowanceErc20: ${allowanceErc20}');

    final estimateGas = await _web3Client.estimateGas();

    print('estimateGas: ${estimateGas}');

    // final addLiquidity = await _web3Client.call(
    //   contract: pancakeRouterContract,
    //   function: pancakeRouterContract.function('addLiquidity'),
    //   params: [
    //     EthereumAddress.fromHex('0x8f92eB3b8d0D91d4F8924a041Ad94a6b6A67E5e9'),
    //     EthereumAddress.fromHex('0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'),
    //     estimateGas,
    //     estimateGas,
    //     estimateGas,
    //     estimateGas,
    //     EthereumAddress.fromHex('0xd99d1c33f9fc3444f8101754abc46c52416550d1'),
    //     BigInt.from(
    //         DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch),
    //   ],
    // );

    // print('addLiquidity: ${addLiquidity}');

    final approveTx = await _web3Client.call(
      contract: erc20Contract,
      function: erc20Contract.function('approve'),
      params: [
        EthereumAddress.fromHex('0xd99d1c33f9fc3444f8101754abc46c52416550d1'),
        estimateGas
      ],
    );

    print('Transaction hash: ${approveTx[0].hash}');

    return;

    // final approveReceipt = await approveTx[0].wait();
    // print('approveReceipt: $approveReceipt');

    final pairAddress = await _web3Client.call(
      contract: pancakeFactoryContract,
      function: pancakeFactoryContract.function('getPair'),
      params: [
        EthereumAddress.fromHex('0x10ED43C718714eb63d5aA57B78B54704E256024E'),
        EthereumAddress.fromHex('0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'),
      ],
    );
    final jackPairContract = DeployedContract(
      ContractAbi.fromJson(jackPair, 'jackPair'),
      EthereumAddress.fromHex(pairAddress[0]),
    );

    final reserves = await _web3Client.call(
      contract: jackPairContract,
      function: jackPairContract.function('getReserves'),
      params: [],
    );

    print('reserves: ${reserves}');

    const usdtAmount = 10;
    final amountInWei = EtherAmount.fromUnitAndValue(
      EtherUnit.wei,
      BigInt.from(usdtAmount * math.pow(10, 18)),
    );

    final swapTx = await _web3Client.call(
      contract: pancakeRouterContract,
      function: pancakeRouterContract.function('swapExactTokensForTokens'),
      params: [
        amountInWei,
        BigInt.from(0),
        [
          EthereumAddress.fromHex('0x8f92eB3b8d0D91d4F8924a041Ad94a6b6A67E5e9'),
          EthereumAddress.fromHex('0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'),
        ],
        EthereumAddress.fromHex('0x622b7352BD13Df3216368e36d421fF9611A1a363'),
        BigInt.from(
            DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch),
      ],
    );

    print('Transaction hash: ${swapTx[0].hash}');
    final swapReceipt = await swapTx[0].wait();
    print('swapReceipt: $swapReceipt');

    // await _web3Client.sendTransaction(
    //   EthPrivateKey.fromInt(_privateKey.value),
    //   Transaction.callContract(
    //     contract: pancakeRouterContract,
    //     function: pancakeRouterContract.function('swapExactTokensForTokens'),
    //     parameters: [
    //       amountInWei,
    //     BigInt.from(0),
    //       [
    //         EthereumAddress.fromHex(
    //             '0x8f92eB3b8d0D91d4F8924a041Ad94a6b6A67E5e9'),
    //         EthereumAddress.fromHex(
    //             '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd'),
    //       ],
    //       EthereumAddress.fromHex('0x622b7352BD13Df3216368e36d421fF9611A1a363'),
    //       BigInt.from(DateTime.now()
    //           .add(const Duration(days: 1))
    //           .millisecondsSinceEpoch),
    //     ],
    //     value: amountInWei,
    //   ),
    //   chainId: chainId.toInt(),
    // );
    showAlertDialog();
    _getBalance(_address);
  }

  void _getTokensBalance() async {
    final erc20 = await _getLocalJson('erc20');
    final contract = DeployedContract(
      ContractAbi.fromJson(erc20, 'erc20'),
      EthereumAddress.fromHex('0x8f92eB3b8d0D91d4F8924a041Ad94a6b6A67E5e9'),
    );
    final balance = await _web3Client.call(
      contract: contract,
      function: contract.function('balanceOf'),
      params: [
        EthereumAddress.fromHex('0x622b7352BD13Df3216368e36d421fF9611A1a363')
      ],
    );

    print('balance ----- ${balance[0] / BigInt.from(math.pow(10, 18))}');
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
