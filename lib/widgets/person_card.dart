import 'package:flutter/material.dart';
import '../models/person.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PersonCard extends StatefulWidget {
  final Person person;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PersonCard({
    super.key,
    required this.person,
    this.onTap,
    this.width = 120,
    this.height = 140,
  });

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _borderColor {
    return widget.person.gender == Gender.male
        ? const Color(0xFF4A90E2)
        : const Color(0xFFE24A90);
  }

  Color get _photoBackgroundColor {
    return widget.person.gender == Gender.male
        ? const Color(0xFF4A90E2)
        : const Color(0xFFE24A90);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _animationController.forward();
      },
      onExit: (_) {
        _animationController.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.width,
                constraints: BoxConstraints(
                  minHeight: widget.height,
                  maxWidth: widget.width,
                ),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _borderColor,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPhoto(),
                      const SizedBox(height: 8),
                      _buildName(),
                      const SizedBox(height: 4),
                      if (widget.person.age != null || widget.person.calculatedAge > 0)
                        _buildAge(),
                      if (widget.person.mid != null && widget.person.mid!.isNotEmpty)
                        _buildMID(),
                      const SizedBox(height: 2),
                      if (widget.person.relationToHead != null && 
                          widget.person.relationToHead!.isNotEmpty &&
                          widget.person.relationToHead != 'none')
                        _buildRelation(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    return CircleAvatar(
      radius: 25,
      backgroundColor: _photoBackgroundColor,
      backgroundImage: widget.person.photoUrl != null
          ? ResizeImage(
              CachedNetworkImageProvider(widget.person.photoUrl!),
              width: 150, // Optimize memory: 50 * 3 (pixel density)
              policy: ResizeImagePolicy.fit,
            ) as ImageProvider
          : null,
      child: widget.person.photoUrl == null
          ? Text(
              widget.person.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
    );
  }

  Widget _buildName() {
    return Text(
      widget.person.fullName,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildAge() {
    return Text(
      'Age: ${widget.person.calculatedAge}',
      style: const TextStyle(
        fontSize: 9,
        color: Color(0xFF666666),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMID() {
    return Text(
      'MID: ${widget.person.mid}',
      style: const TextStyle(
        fontSize: 8,
        color: Color(0xFF4A90E2),
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildRelation() {
    String relationText = widget.person.relationToHead!;
    // Format relation text
    relationText = relationText.replaceAll('_', ' ');
    relationText = relationText.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: _borderColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        relationText,
        style: TextStyle(
          fontSize: 7,
          color: _borderColor,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}
