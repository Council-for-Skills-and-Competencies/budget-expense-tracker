import 'dart:async';
import 'dart:io' show Platform;
import 'package:animations/animations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// Models
@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String? name;
  @HiveField(1)
  int? age;
  @HiveField(2)
  DateTime? dob;
  @HiveField(3)
  String? designation;
  @HiveField(4)
  double? salary;
  @HiveField(5)
  String? email;

  UserModel({
    this.name,
    this.age,
    this.dob,
    this.designation,
    this.salary,
    this.email,
  });
}

@HiveType(typeId: 1)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  String category;
  @HiveField(1)
  double amount;
  @HiveField(2)
  DateTime date;

  ExpenseModel({
    required this.category,
    required this.amount,
    required this.date,
  });
}

@HiveType(typeId: 2)
class BudgetModel extends HiveObject {
  @HiveField(0)
  String category;
  @HiveField(1)
  double allocated;
  @HiveField(2)
  double spent;

  BudgetModel({
    required this.category,
    required this.allocated,
    this.spent = 0.0,
  });
}

// Hive Adapters
class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 0;

  @override
  UserModel read(BinaryReader reader) {
    return UserModel(
      name: reader.read(),
      age: reader.read(),
      dob: reader.read(),
      designation: reader.read(),
      salary: reader.read(),
      email: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer.write(obj.name);
    writer.write(obj.age);
    writer.write(obj.dob);
    writer.write(obj.designation);
    writer.write(obj.salary);
    writer.write(obj.email);
  }
}

class ExpenseModelAdapter extends TypeAdapter<ExpenseModel> {
  @override
  final int typeId = 1;

  @override
  ExpenseModel read(BinaryReader reader) {
    return ExpenseModel(
      category: reader.read(),
      amount: reader.read(),
      date: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseModel obj) {
    writer.write(obj.category);
    writer.write(obj.amount);
    writer.write(obj.date);
  }
}

class BudgetModelAdapter extends TypeAdapter<BudgetModel> {
  @override
  final int typeId = 2;

  @override
  BudgetModel read(BinaryReader reader) {
    return BudgetModel(
      category: reader.read(),
      allocated: reader.read(),
      spent: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, BudgetModel obj) {
    writer.write(obj.category);
    writer.write(obj.allocated);
    writer.write(obj.spent);
  }
}

// Services
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Box userBox = Hive.box('userBox');

  Future<User?> signUp(String email, String password, UserModel userData) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _auth.currentUser?.sendEmailVerification();
      await userBox.put('user', userData);
      
      return result.user;
    } catch (e) {
      
      print('Signup error: $e');
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!result.user!.emailVerified) {

        throw Exception('Email not verified');
      }
      
      return result.user;
    } catch (e) {
      
      print('Login error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    print('User logged out, but data preserved in Hive');
  }

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
    await userBox.clear();
    await Hive.box('expenseBox').clear();
    await Hive.box('budgetBox').clear();
  }
}

class BudgetService {
  final Box budgetBox = Hive.box('budgetBox');
  final Box expenseBox = Hive.box('expenseBox');
  final Box userBox = Hive.box('userBox');

  final List<Map<String, dynamic>> salaryRanges = [
    {'min': 10000, 'max': 20000, 'rent': 0.24, 'foodgroceries': 0.28, 'travel': 0.10, 'clothing': 0.05, 'entertainment': 0.03, 'accessories': 0.02, 'emidebt': 0.12, 'savingsinvestments': 0.16},
    {'min': 20000, 'max': 30000, 'rent': 0.23, 'foodgroceries': 0.23, 'travel': 0.10, 'clothing': 0.06, 'entertainment': 0.05, 'accessories': 0.03, 'emidebt': 0.11, 'savingsinvestments': 0.19},
    {'min': 30000, 'max': 40000, 'rent': 0.21, 'foodgroceries': 0.19, 'travel': 0.10, 'clothing': 0.07, 'entertainment': 0.06, 'accessories': 0.03, 'emidebt': 0.10, 'savingsinvestments': 0.24},
    {'min': 40000, 'max': 50000, 'rent': 0.19, 'foodgroceries': 0.18, 'travel': 0.10, 'clothing': 0.08, 'entertainment': 0.07, 'accessories': 0.05, 'emidebt': 0.09, 'savingsinvestments': 0.29},
    {'min': 50000, 'max': 60000, 'rent': 0.16, 'foodgroceries': 0.16, 'travel': 0.09, 'clothing': 0.08, 'entertainment': 0.08, 'accessories': 0.05, 'emidebt': 0.09, 'savingsinvestments': 0.33},
    {'min': 60000, 'max': double.infinity, 'rent': 0.13, 'foodgroceries': 0.15, 'travel': 0.09, 'clothing': 0.10, 'entertainment': 0.09, 'accessories': 0.05, 'emidebt': 0.09, 'savingsinvestments': 0.40},
  ];

  final Map<String, String> categoryKeys = {
    'Rent': 'rent',
    'Food & Groceries': 'foodgroceries',
    'Travel': 'travel',
    'Clothing': 'clothing',
    'Entertainment': 'entertainment',
    'Accessories': 'accessories',
    'EMI/Debt': 'emidebt',
    'Savings & Investments': 'savingsinvestments',
  };

  final Map<String, IconData> categoryIcons = {
    'Rent': Icons.home_rounded,
    'Food & Groceries': Icons.restaurant_rounded,
    'Travel': Icons.directions_car_rounded,
    'Clothing': Icons.shopping_bag_rounded,
    'Entertainment': Icons.movie_rounded,
    'Accessories': Icons.watch_rounded,
    'EMI/Debt': Icons.credit_card_rounded,
    'Savings & Investments': Icons.savings_rounded,
  };

  final Map<String, String> categoryEmojis = {
    'Rent': '🏠',
    'Food & Groceries': '🍎',
    'Travel': '🚗',
    'Clothing': '👗',
    'Entertainment': '🎬',
    'Accessories': '⌚',
    'EMI/Debt': '💳',
    'Savings & Investments': '💰',
  };

  final Map<String, Color> categoryColors = {
    'Rent': const Color(0xFF4361EE),
    'Food & Groceries': const Color(0xFF06D6A0),
    'Travel': const Color(0xFFFFD166),
    'Clothing': const Color(0xFFEF476F),
    'Entertainment': const Color(0xFFF72585),
    'Accessories': const Color(0xFF7209B7),
    'EMI/Debt': const Color(0xFFF3722C),
    'Savings & Investments': const Color(0xFF118AB2),
  };

  void updateBudgets(double salary) {
    categoryKeys.forEach((cat, key) {
      var range = salaryRanges.firstWhere(
        (r) => salary >= r['min'] && salary < r['max'],
        orElse: () => salaryRanges.last,
      );
      double percent = range[key] ?? 0.0;
      double allocated = salary * percent;

      BudgetModel? existingBudget = budgetBox.get(cat) as BudgetModel?;
      if (existingBudget != null) {
        existingBudget.allocated = allocated;
        existingBudget.save();
      } else {
        budgetBox.put(cat, BudgetModel(category: cat, allocated: allocated));
      }
    });
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await expenseBox.add(expense);
    BudgetModel? budget = budgetBox.get(expense.category) as BudgetModel?;
    if (budget != null) {
      budget.spent += expense.amount;
      await budget.save();
    }
  }

  double getRemainingBalance() {
    UserModel? user = userBox.get('user') as UserModel?;
    double salary = user?.salary ?? 0.0;
    double totalSpent = budgetBox.values.fold(0.0, (sum, dynamic b) => sum + (b as BudgetModel).spent);
    return salary - totalSpent;
  }

  List<BudgetModel> getBudgets() {
    return budgetBox.values.map((dynamic e) => e as BudgetModel).toList();
  }

  List<ExpenseModel> getExpensesForCategory(String category) {
    return expenseBox.values
        .map((dynamic e) => e as ExpenseModel)
        .where((expense) => expense.category == category)
        .toList();
  }
}

// Main App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

  // ✅ Register adapters BEFORE opening boxes
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(ExpenseModelAdapter());
  Hive.registerAdapter(BudgetModelAdapter());

  await Hive.openBox('userBox');
  await Hive.openBox('expenseBox');
  await Hive.openBox('budgetBox');

  runApp(const MoneyMindApp());
}

class MoneyMindApp extends StatelessWidget {
  const MoneyMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyMind',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4361EE),
          primary: const Color(0xFF4361EE),
          secondary: const Color(0xFF06D6A0),
          background: const Color(0xFFF8F9FA),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).copyWith(
          headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF212529)),
          headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF212529)),
          bodyLarge: GoogleFonts.poppins(color: const Color(0xFF495057)),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF4361EE)),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212529),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4361EE),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFFE9ECEF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFFE9ECEF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF4361EE), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          color: Colors.white,
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Screens
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.emailVerified) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'MoneyMind',
                style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Smart Budget Management',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _login() async {
    setState(() => _isLoading = true);
    var user = await _auth.login(_emailController.text, _passwordController.text);
    setState(() => _isLoading = false);

    if (user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login successful!'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed. Please check credentials or verify email.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('Welcome Back', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Sign in to continue to MoneyMind', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_rounded, color: Theme.of(context).colorScheme.primary),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_rounded, color: Theme.of(context).colorScheme.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    child: Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyLarge,
                      children: [
                        TextSpan(
                          text: 'Sign up',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();
  final _designationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _auth = AuthService();
  final BudgetService _budgetService = BudgetService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isLoading = true);

    UserModel userData = UserModel(
      name: _nameController.text,
      age: int.tryParse(_ageController.text),
      dob: DateTime.tryParse(_dobController.text),
      designation: _designationController.text,
      salary: double.tryParse(_salaryController.text),
      email: _emailController.text,
    );

    var user = await _auth.signUp(_emailController.text, _passwordController.text, userData);
    setState(() => _isLoading = false);

    if (user != null) {
      _budgetService.updateBudgets(userData.salary ?? 0.0);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Verify Email'),
          content: Text('A verification email has been sent. Please check your inbox.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Account', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Fill in your details to get started', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextField(controller: _nameController, decoration: _inputDecoration('Full Name', Icons.person_rounded)),
            const SizedBox(height: 16),
            TextField(controller: _ageController, decoration: _inputDecoration('Age', Icons.cake_rounded), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(controller: _dobController, decoration: _inputDecoration('Date of Birth (YYYY-MM-DD)', Icons.calendar_today_rounded)),
            const SizedBox(height: 16),
            TextField(controller: _designationController, decoration: _inputDecoration('Designation', Icons.work_rounded)),
            const SizedBox(height: 16),
            TextField(controller: _salaryController, decoration: _inputDecoration('Monthly Salary', Icons.attach_money_rounded), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(controller: _emailController, decoration: _inputDecoration('Email', Icons.email_rounded), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_rounded, color: Theme.of(context).colorScheme.primary),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_rounded, color: Theme.of(context).colorScheme.primary),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              obscureText: _obscureConfirmPassword,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signup,
                  child: Text('Create Account', style: TextStyle(fontSize: 16)),
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: RichText(
                  text: TextSpan(
                    text: "Already have an account? ",
                    style: Theme.of(context).textTheme.bodyLarge,
                    children: [
                      TextSpan(
                        text: 'Sign in',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _designationController.dispose();
    _salaryController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BudgetService _budgetService = BudgetService();
  final AuthService _auth = AuthService();

  Widget _buildBalanceCard(String title, String amount, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(amount, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MoneyMind'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary),
            onPressed: () => Navigator.push(context, PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ProfileScreen(),
              transitionsBuilder: (_, animation, __, child) => FadeScaleTransition(animation: animation, child: child),
            )),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _budgetService.budgetBox.listenable(),
        builder: (context, box, _) {
          List<BudgetModel> budgets = _budgetService.getBudgets();
          double remaining = _budgetService.getRemainingBalance();
          UserModel? user = _budgetService.userBox.get('user') as UserModel?;

          return ResponsiveBuilder(
            builder: (context, sizingInfo) {
              double chartSize = sizingInfo.isDesktop ? 400 : 250;

              return SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Icon(Icons.person_rounded, size: 30, color: Theme.of(context).colorScheme.primary),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Welcome back,', style: Theme.of(context).textTheme.bodyLarge),
                                  Text(user?.name ?? 'User', style: Theme.of(context).textTheme.headlineMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Balance Overview
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Balance Overview', style: Theme.of(context).textTheme.headlineSmall),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildBalanceCard('Remaining', '₹${remaining.toStringAsFixed(2)}', Theme.of(context).colorScheme.primary)),
                                SizedBox(width: 16),
                                Expanded(child: _buildBalanceCard('Total Budget', '₹${(user?.salary ?? 0).toStringAsFixed(2)}', Theme.of(context).colorScheme.secondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Chart
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Budget Progress', style: Theme.of(context).textTheme.headlineSmall),
                                IconButton(
                                  icon: Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sections: budgets.map((b) {
                                    double percent = b.allocated > 0 ? (b.spent / b.allocated * 100) : 0;
                                    return PieChartSectionData(
                                      value: b.spent,
                                      title: '${percent.toStringAsFixed(0)}%',
                                      color: _budgetService.categoryColors[b.category] ?? Colors.grey,
                                      radius: 70,
                                      titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceColor: Colors.grey[50],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
//                     Card(
//   child: Padding(
//     padding: const EdgeInsets.all(20),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text('Budget Progress', style: Theme.of(context).textTheme.headlineSmall),
//             IconButton(
//               icon: Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.primary),
//               onPressed: () {},
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         // Use ValueListenableBuilder to listen for changes in the budget data
//         SizedBox(
//           height: 250,
//           child: ValueListenableBuilder(
//             valueListenable: _budgetService.budgetBox.listenable(),
//             builder: (context, box, widget) {
//               // Get fresh data each time the box changes
//               List<BudgetModel> currentBudgets = _budgetService.getBudgets();
              
//               return ListView.builder(
//                 itemCount: currentBudgets.length,
//                 itemBuilder: (context, index) {
//                   final budget = currentBudgets[index];
//                   final double spentPercent = budget.allocated > 0 
//                     ? (budget.spent / budget.allocated) 
//                     : 0;
//                   final double clampedPercent = spentPercent.clamp(0.0, 1.0);
                  
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Container(
//                               width: 12,
//                               height: 12,
//                               decoration: BoxDecoration(
//                                 color: _budgetService.categoryColors[budget.category] ?? 
//                                   Theme.of(context).colorScheme.primary,
//                                 shape: BoxShape.circle,
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Text(
//                               budget.category, 
//                               style: const TextStyle(fontWeight: FontWeight.bold)
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         Container(
//                           height: 20,
//                           decoration: BoxDecoration(
//                             color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Stack(
//                             children: [
//                               // Spent amount (foreground) - FIXED
//                               FractionallySizedBox(
//                                 widthFactor: clampedPercent,
//                                 child: Container(
//                                   decoration: BoxDecoration(
//                                     color: _budgetService.categoryColors[budget.category] ?? 
//                                       Theme.of(context).colorScheme.primary,
//                                     borderRadius: BorderRadius.circular(4),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text('Spent: ₹${budget.spent.toStringAsFixed(2)}'),
//                             Text('Allocated: ₹${budget.allocated.toStringAsFixed(2)} (${(clampedPercent * 100).toStringAsFixed(1)}%)'),
//                           ],
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//       ],
//     ),
//   ),
// ),
                    SizedBox(height: 16),

                    // Quick Actions
                    Text('Quick Actions', style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildActionButton('Add Expense', Icons.add_rounded, Theme.of(context).colorScheme.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())))),
                        SizedBox(width: 12),
                        Expanded(child: _buildActionButton('View Reports', Icons.analytics_rounded, Theme.of(context).colorScheme.secondary, () {})),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Category Analytics
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Category Analytics', style: Theme.of(context).textTheme.headlineSmall),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                          child: Text('View All'),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: budgets.length > 3 ? 3 : budgets.length,
                      itemBuilder: (_, index) {
                        var b = budgets[index];
                        bool exceeded = b.spent > b.allocated;
                        double percent = b.allocated > 0 ? (b.spent / b.allocated * 100) : 0;
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _budgetService.categoryColors[b.category]?.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _budgetService.categoryIcons[b.category],
                                size: 20,
                                color: _budgetService.categoryColors[b.category],
                              ),
                            ),
                            title: Text(b.category),
                            subtitle: Text('Spent: ₹${b.spent.toStringAsFixed(2)} / Allocated: ₹${b.allocated.toStringAsFixed(2)} (${percent.toStringAsFixed(0)}%)'),
                            trailing: exceeded
                                ? Icon(Icons.warning_amber_rounded, color: Colors.red)
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BudgetService _budgetService = BudgetService();
    List<String> categories = _budgetService.budgetBox.keys.cast<String>().toList();

    return Scaffold(
      appBar: AppBar(title: Text('Categories')),
      body: ResponsiveBuilder(
        builder: (context, sizingInfo) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No categories available.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      UserModel? user = _budgetService.userBox.get('user') as UserModel?;
                      if (user != null && user.salary != null) {
                        _budgetService.updateBudgets(user.salary!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Categories generated based on your salary')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please update your salary in Profile first')),
                        );
                      }
                    },
                    child: Text('Generate Categories'),
                  ),
                ],
              ),
            );
          }

          int columns = sizingInfo.isMobile ? 2 : sizingInfo.isTablet ? 3 : 4;
          double cardSize = kIsWeb ? 120 : (Platform.isIOS || Platform.isAndroid) ? 120 : 160;

          return LayoutGrid(
            columnSizes: List.filled(columns, 1.fr),
            rowSizes: List.filled((categories.length / columns).ceil(), cardSize.px),
            children: categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Card(
                  color: _budgetService.categoryColors[cat],
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseEntryScreen(category: cat))),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_budgetService.categoryEmojis[cat] ?? '❓', style: TextStyle(fontSize: cardSize * 0.3)),
                          SizedBox(height: 8),
                          Text(cat, style: TextStyle(fontSize: cardSize * 0.1, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class ExpenseEntryScreen extends StatefulWidget {
  final String category;
  const ExpenseEntryScreen({super.key, required this.category});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _amountController = TextEditingController();
  final BudgetService _budgetService = BudgetService();

  void _addExpense() async {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    BudgetModel? budget = _budgetService.budgetBox.get(widget.category) as BudgetModel?;
    if (budget != null) {
      double newSpent = budget.spent + amount;
      if (newSpent > budget.allocated) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warning: Budget for ${widget.category} exceeded!')));
      }

      await _budgetService.addExpense(ExpenseModel(
        category: widget.category,
        amount: amount,
        date: DateTime.now(),
      ));

      _amountController.clear();
    }
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _budgetService.budgetBox.listenable(),
      builder: (context, box, _) {
        BudgetModel? budget = _budgetService.budgetBox.get(widget.category) as BudgetModel?;
        List<ExpenseModel> expenses = _budgetService.getExpensesForCategory(widget.category);

        return Scaffold(
          appBar: AppBar(title: Text('Add Expense for ${widget.category}')),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Current: ₹${budget?.spent.toStringAsFixed(2) ?? '0.00'} / Allocated: ₹${budget?.allocated.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 24),
                ElevatedButton(onPressed: _addExpense, child: Text('Add Expense')),
                SizedBox(height: 24),
                Text('Recent Expenses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _budgetService.expenseBox.listenable(),
                    builder: (context, box, _) {
                      if (expenses.isEmpty) {
                        return Center(child: Text('No expenses recorded yet.'));
                      }
                      return ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final e = expenses[index];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text('₹${e.amount.toStringAsFixed(2)}'),
                              subtitle: Text(DateFormat.yMMMd().format(e.date)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final BudgetService _budgetService = BudgetService();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _dobController;
  late TextEditingController _designationController;
  late TextEditingController _salaryController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    UserModel? user = _auth.userBox.get('user') as UserModel?;
    _nameController = TextEditingController(text: user?.name ?? '');
    _ageController = TextEditingController(text: user?.age?.toString() ?? '');
    _dobController = TextEditingController(text: user?.dob != null ? DateFormat('yyyy-MM-dd').format(user!.dob!) : '');
    _designationController = TextEditingController(text: user?.designation ?? '');
    _salaryController = TextEditingController(text: user?.salary?.toString() ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _designationController.dispose();
    _salaryController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _updateProfile() async {
    double newSalary = double.tryParse(_salaryController.text) ?? 0.0;
    UserModel updatedUser = UserModel(
      name: _nameController.text,
      age: int.tryParse(_ageController.text),
      dob: DateTime.tryParse(_dobController.text),
      designation: _designationController.text,
      salary: newSalary,
      email: _emailController.text,
    );
    await _auth.userBox.put('user', updatedUser);
    _budgetService.updateBudgets(newSalary);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated successfully')));
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () async {
              await _auth.deleteAccount();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
            child: Text('Yes', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('No')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: _inputDecoration('Full Name', Icons.person_rounded)),
            SizedBox(height: 16),
            TextField(controller: _ageController, decoration: _inputDecoration('Age', Icons.cake_rounded), keyboardType: TextInputType.number),
            SizedBox(height: 16),
            TextField(controller: _dobController, decoration: _inputDecoration('DOB (YYYY-MM-DD)', Icons.calendar_today_rounded)),
            SizedBox(height: 16),
            TextField(controller: _designationController, decoration: _inputDecoration('Designation', Icons.work_rounded)),
            SizedBox(height: 16),
            TextField(controller: _salaryController, decoration: _inputDecoration('Monthly Salary', Icons.attach_money_rounded), keyboardType: TextInputType.number),
            SizedBox(height: 16),
            TextField(controller: _emailController, decoration: _inputDecoration('Email', Icons.email_rounded), enabled: false),
            SizedBox(height: 24),
            ElevatedButton(onPressed: _updateProfile, child: Text('Update Profile')),
            SizedBox(height: 16),
            TextButton(onPressed: _deleteAccount, child: Text('Delete Account', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }
}


