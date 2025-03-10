import 'package:flutter/material.dart';

class AuthenticationImage extends StatelessWidget {
  const AuthenticationImage({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double imageHeight = screenHeight * 0.42;
    double imageHeight2 = screenHeight * 0.4;
    double imageWidth = screenWidth * 0.8;

    return SizedBox(
      width: screenWidth,
      height: imageHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 20,
            left: -(screenWidth * 0.15),
            child: Container(
              width: screenWidth * 0.3,
              height: screenWidth * 0.3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6750A4),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: screenWidth * 0.3,
              height: screenWidth * 0.3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6750A4),
              ),
            ),
          ),
          // Right Circle
          Positioned(
            top: imageHeight * 0.7,
            right: -30,
            child: Container(
              width: screenWidth * 0.25,
              height: screenWidth * 0.25,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6750A4),
              ),
            ),
          ),
          Positioned(
            top: 5,
            child: Image.asset(
              'assets/images/authentication/authenticationImage.png',
              width: imageWidth,
              height: imageHeight2,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
