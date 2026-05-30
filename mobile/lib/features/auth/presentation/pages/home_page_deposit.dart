/// Thiago Ryuji Ogawa - RA:24024450
///
/// Parte da implementacao da home dedicada ao deposito ficticio.
/// Mantem isolada a interface para credito de saldo sem poluir
/// o arquivo principal da tela.

part of 'home_page.dart';

enum _PortfolioAction { deposit }

class _DepositAmountPage extends StatefulWidget {
  const _DepositAmountPage();

  @override
  State<_DepositAmountPage> createState() => _DepositAmountPageState();
}

class _DepositAmountPageState extends State<_DepositAmountPage> {
  late final TextEditingController _amountController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = _amountController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(normalized);

    if (amount == null || amount <= 0) {
      setState(() {
        _errorText = 'Informe um valor valido.';
      });
      return;
    }

    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F10),
        foregroundColor: Colors.white,
        title: const Text('Depositar saldo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF17191D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF292D34)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Depositar saldo ficticio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Informe o valor que deseja adicionar ao saldo.',
                  style: TextStyle(color: Color(0xFFB7BCC8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Valor do deposito',
                    hintText: 'Ex.: 10000',
                    hintStyle: const TextStyle(color: Color(0xFF8B909C)),
                    errorText: _errorText,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Confirmar deposito'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
