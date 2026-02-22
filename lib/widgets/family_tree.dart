import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/person.dart';
import 'person_card.dart';
import 'person_detail_dialog.dart';

class FamilyTree extends StatefulWidget {
  final List<List<Person>> generations;
  final double cardWidth;
  final double cardHeight;
  final double generationSpacing;
  final double siblingSpacing;

  const FamilyTree({
    super.key,
    required this.generations,
    this.cardWidth = 120,
    this.cardHeight = 140,
    this.generationSpacing = 60,
    this.siblingSpacing = 15,
  });

  @override
  State<FamilyTree> createState() => _FamilyTreeState();
}

class _FamilyTreeState extends State<FamilyTree> {
  final Map<String, GlobalKey> _cardKeys = {};
  final Map<String, Rect> _cardPositions = {};
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Initialize card keys for all persons
    for (final generation in widget.generations) {
      for (final person in generation) {
        _cardKeys[person.id] = GlobalKey();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, 
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(1000), 
        minScale: 0.1,
        maxScale: 3.0,
        constrained: false, 
        child: Padding(
          padding: const EdgeInsets.all(200), 
          child: CustomPaint(
            key: _contentKey,
            painter: _FamilyTreePainter(
              generations: widget.generations,
              cardPositions: _cardPositions,
              generationSpacing: widget.generationSpacing,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildGenerations(context),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGenerations(BuildContext context) {
    List<Widget> generationWidgets = [];
    
    for (int i = 0; i < widget.generations.length; i++) {
      generationWidgets.add(_buildGeneration(context, widget.generations[i], i));
      
      if (i < widget.generations.length - 1) {
        generationWidgets.add(SizedBox(height: widget.generationSpacing));
      }
    }
    
    // Update positions after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateCardPositions();
      }
    });
    
    return generationWidgets;
  }

  void _updateCardPositions() {
    final RenderBox? treeBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (treeBox == null) return;

    final Map<String, Rect> newPositions = {};
    bool significantChange = false;

    for (final entry in _cardKeys.entries) {
      final RenderBox? cardBox = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (cardBox != null) {
        final position = cardBox.localToGlobal(Offset.zero, ancestor: treeBox);
        final size = cardBox.size;
        final rect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
        
        // Small threshold to avoid floating point noise triggering rebuilds
        if (!_cardPositions.containsKey(entry.key) || 
            (newPositions[entry.key] != null && (newPositions[entry.key]!.topLeft - rect.topLeft).distance > 0.5)) {
          significantChange = true;
        }
        newPositions[entry.key] = rect;
      }
    }
    
    // Check if lengths are different or significantChange detected
    if ((significantChange || newPositions.length != _cardPositions.length) && mounted) {
      // Use future.microtask to avoid triggering during current build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _cardPositions.clear();
            _cardPositions.addAll(newPositions);
          });
        }
      });
    }
  }

  Widget _buildGeneration(BuildContext context, List<Person> people, int generationIndex) {
    // 1. Group people into basic units (couples or individuals)
    final List<dynamic> baseUnits = []; // Can be Person (single) or List<Person> (couple)
    final processed = <String>{};

    for (int i = 0; i < people.length; i++) {
      final person = people[i];
      if (processed.contains(person.id)) continue;

      if (person.spouseId != null) {
        final spouseIndex = people.indexWhere((p) => p.mid == person.spouseId);
        if (spouseIndex != -1 && !processed.contains(people[spouseIndex].id)) {
          baseUnits.add([person, people[spouseIndex]]);
          processed.add(person.id);
          processed.add(people[spouseIndex].id);
          continue;
        }
      }

      baseUnits.add(person);
      processed.add(person.id);
    }

    // 2. Group units into rows
    // Singles group together (up to 3), couples stay in their own row
    final List<Widget> rows = [];
    List<Person> currentSinglesGroup = [];

    void flushSingles() {
      if (currentSinglesGroup.isNotEmpty) {
        rows.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: currentSinglesGroup.map((p) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.siblingSpacing),
                child: _buildAnimatedPerson(context, p, generationIndex, people.indexOf(p)),
              );
            }).toList(),
          )
        );
        currentSinglesGroup = [];
      }
    }

    for (final unit in baseUnits) {
      if (unit is List<Person>) {
        // Married couple - needs its own row
        flushSingles();
        rows.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnimatedPerson(context, unit[0], generationIndex, people.indexOf(unit[0])),
              SizedBox(width: widget.siblingSpacing),
              _buildAnimatedPerson(context, unit[1], generationIndex, people.indexOf(unit[1])),
            ],
          )
        );
      } else {
        // Single person - group with other singles
        currentSinglesGroup.add(unit as Person);
        if (currentSinglesGroup.length >= 3) {
          flushSingles();
        }
      }
    }
    flushSingles();

    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rows.map((row) => Padding(
          padding: EdgeInsets.only(bottom: widget.siblingSpacing * 3),
          child: row,
        )).toList(),
      ),
    );
  }

  Widget _buildAnimatedPerson(BuildContext context, Person person, int generationIndex, int index) {
    // Remove SlideInAnimation here as it triggers continuous layout updates 
    // during the animation period, causing infinite rebuild cycles with CustomPainter.
    return _buildPersonCard(context, person);
  }

  Widget _buildPersonCard(BuildContext context, Person person) {
    return Container(
      key: _cardKeys[person.id],
      child: PersonCard(
        person: person,
        width: widget.cardWidth,
        height: widget.cardHeight,
        onTap: () => _showPersonDetails(context, person),
      ),
    );
  }

  void _showPersonDetails(BuildContext context, Person person) {
    showDialog(
      context: context,
      builder: (context) => PersonDetailDialog(person: person),
    );
  }
}

// We need a prefix or different way to avoid Rect collision if needed, but Flutter's Rect is fine.
// Using dart:ui Rect explicitly or just trust the scope.
// Custom painter to draw connecting lines between family members
class _FamilyTreePainter extends CustomPainter {
  final List<List<Person>> generations;
  final Map<String, Rect> cardPositions;
  final double generationSpacing;

  _FamilyTreePainter({
    required this.generations,
    required this.cardPositions,
    required this.generationSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cardPositions.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF4A90E2).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final processedCouples = <String>{};

    // Draw lines from parents to children
    for (int genIndex = 0; genIndex < generations.length - 1; genIndex++) {
      final currentGen = generations[genIndex];
      final nextGen = generations[genIndex + 1];

      // Group people in currentGen by family units (couples or single parents)
      for (final person in currentGen) {
        if (processedCouples.contains(person.id)) continue;

        Offset? sourcePos;
        
        final parentRect = cardPositions[person.id];
        if (parentRect == null) continue;

        if (person.spouseId != null && cardPositions.containsKey(person.spouseId)) {
          final spouseRect = cardPositions[person.spouseId]!;
          
          // Draw marriage line (black and bold as per user request)
          final marriagePaint = Paint()
            ..color = Colors.black87
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(
            Offset(math.min(parentRect.right, spouseRect.right), parentRect.center.dy),
            Offset(math.max(parentRect.left, spouseRect.left), parentRect.center.dy),
            marriagePaint,
          );

          // Family branch point is midpoint between they two cards
          sourcePos = Offset((parentRect.center.dx + spouseRect.center.dx) / 2, parentRect.center.dy);
          processedCouples.add(person.id);
          processedCouples.add(person.spouseId!);
        } else {
          // Single parent
          sourcePos = Offset(parentRect.center.dx, parentRect.bottom);
          processedCouples.add(person.id);
        }

        // Find children of this parent (or spouse)
        final children = nextGen.where((child) => 
          child.parentIds.contains(person.mid) || 
          (person.spouseId != null && child.parentIds.contains(person.spouseId))
        ).toList();

        if (children.isEmpty) continue;

        // Get children target positions (top center of the child's unit)
        final List<double> childTargetXs = [];

        for (final child in children) {
          final childRect = cardPositions[child.id];
          if (childRect == null) continue;

          // Check if child is part of a couple in the next generation to center the line
          if (child.spouseId != null && cardPositions.containsKey(child.spouseId)) {
             final childSpouseRect = cardPositions[child.spouseId]!;
             // Target X is center of the child couple
             childTargetXs.add((childRect.center.dx + childSpouseRect.center.dx) / 2);
          } else {
             childTargetXs.add(childRect.center.dx);
          }
        }

        if (children.isEmpty) continue;

        // Get children target points
        final List<Offset> childTargets = [];
        for (final child in children) {
          final childRect = cardPositions[child.id];
          if (childRect == null) continue;

          double targetX;
          if (child.spouseId != null && cardPositions.containsKey(child.spouseId)) {
            final childSpouseRect = cardPositions[child.spouseId]!;
            targetX = (childRect.center.dx + childSpouseRect.center.dx) / 2;
          } else {
            targetX = childRect.center.dx;
          }
          childTargets.add(Offset(targetX, childRect.center.dy));
        }

        if (childTargets.isEmpty) continue;

        // Draw Vertical Spine Layout
        // 1. Vertical spine from source down to the last child's Y
        final lastChildY = childTargets.last.dy;
        
        // Use a slightly offset X if children are centered to avoid going THROUGH them?
        // Actually, user might want it to the left. Let's see.
        // For now, draw it at sourceX and let's see how it looks.
        // If sourcePos.dx == all childTarget.dx, it's just one vertical line.
        
        canvas.drawLine(
          sourcePos,
          Offset(sourcePos.dx, lastChildY),
          paint,
        );

        // 2. Horizontal branches from spine to each child
        for (final target in childTargets) {
          if (target.dx != sourcePos.dx) {
            canvas.drawLine(
              Offset(sourcePos.dx, target.dy),
              target,
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FamilyTreePainter oldDelegate) {
    return cardPositions != oldDelegate.cardPositions ||
        generations != oldDelegate.generations;
  }
}
