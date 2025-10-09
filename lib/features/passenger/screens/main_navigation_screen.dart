import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'favourites_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FavouritesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, -2),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              elevation: 0,
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xFF3B82F6).withOpacity(0.1),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: Icon(
                    Icons.home_outlined,
                    color: _currentIndex == 0 ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                  ),
                  selectedIcon: const Icon(
                    Icons.home,
                    color: Color(0xFF3B82F6),
                  ),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.favorite_outline,
                    color: _currentIndex == 1 ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                  ),
                  selectedIcon: const Icon(
                    Icons.favorite,
                    color: Color(0xFF3B82F6),
                  ),
                  label: 'Favourites',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.person_outline,
                    color: _currentIndex == 2 ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                  ),
                  selectedIcon: const Icon(
                    Icons.person,
                    color: Color(0xFF3B82F6),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
