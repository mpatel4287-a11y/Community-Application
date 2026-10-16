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
        _cardKeys.putIfAbsent(person.id, () => GlobalKey());
      }
    }
  }

  @override
  void didUpdateWidget(FamilyTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final generation in widget.generations) {
      for (final person in generation) {
        _cardKeys.putIfAbsent(person.id, () => GlobalKey());
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
              lineColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              marriageColor: Theme.of(context).colorScheme.onSurface,
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
    final List<Widget> unitWidgets = [];
    final processed = <String>{};

    for (int i = 0; i < people.length; i++) {
      final person = people[i];
      if (processed.contains(person.id)) continue;

      Person? spouse;
      if (person.spouseId != null) {
        for (final p in people) {
          if (!processed.contains(p.id) &&
              p.id != person.id &&
              (p.id == person.spouseId || (p.mid != null && p.mid == person.spouseId))) {
            spouse = p;
            break;
          }
        }
      }

      if (spouse != null) {
        processed.add(person.id);
        processed.add(spouse.id);

        Person husband = person;
        Person wife = spouse;
        if (person.gender == Gender.female && spouse.gender == Gender.male) {
          husband = spouse;
          wife = person;
        }

        unitWidgets.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPersonCard(context, husband),
              SizedBox(width: widget.siblingSpacing * 1.5),
              _buildPersonCard(context, wife),
            ],
          ),
        );
      } else {
        processed.add(person.id);
        unitWidgets.add(
          _buildPersonCard(context, person),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < unitWidgets.length; i++) ...[
          if (i > 0) SizedBox(width: widget.siblingSpacing * 2.5),
          unitWidgets[i],
        ],
      ],
    );
  }

  Widget _buildPersonCard(BuildContext context, Person person) {
    final key = _cardKeys.putIfAbsent(person.id, () => GlobalKey());
    return Container(
      key: key,
      child: PersonCard(
        person: person,
        width: widget.cardWidth,
        height: widget.cardHeight,
        onTap: person.isLate ? null : () => _showPersonDetails(context, person),
      ),
    );
  }

  void _showPersonDetails(BuildContext context, Person person) {
    if (person.isLate) return;
    showDialog(
      context: context,
      builder: (context) => PersonDetailDialog(person: person),
    );
  }
}

// Custom painter to draw connecting lines between family members
class _FamilyTreePainter extends CustomPainter {
  final List<List<Person>> generations;
  final Map<String, Rect> cardPositions;
  final double generationSpacing;
  final Color lineColor;
  final Color marriageColor;

  _FamilyTreePainter({
    required this.generations,
    required this.cardPositions,
    required this.generationSpacing,
    required this.lineColor,
    required this.marriageColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cardPositions.isEmpty) return;

    final marriagePaint = Paint()
      ..color = marriageColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final treePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final processedCouples = <String>{};

    // 1. Draw marriage double lines between spouses
    for (final generation in generations) {
      for (final person in generation) {
        if (processedCouples.contains(person.id)) continue;
        if (person.spouseId == null) continue;

        Person? spouse;
        for (final g in generations) {
          for (final p in g) {
            if (p.id != person.id &&
                (p.id == person.spouseId || (p.mid != null && p.mid == person.spouseId))) {
              spouse = p;
              break;
            }
          }
          if (spouse != null) break;
        }

        if (spouse == null) continue;
        processedCouples.add(person.id);
        processedCouples.add(spouse.id);

        final r1 = cardPositions[person.id];
        final r2 = cardPositions[spouse.id];
        if (r1 == null || r2 == null) continue;

        final leftRect = r1.center.dx < r2.center.dx ? r1 : r2;
        final rightRect = r1.center.dx < r2.center.dx ? r2 : r1;

        final midY = (leftRect.center.dy + rightRect.center.dy) / 2;
        final startX = leftRect.right;
        final endX = rightRect.left;

        if (endX > startX) {
          canvas.drawLine(
            Offset(startX, midY - 2.5),
            Offset(endX, midY - 2.5),
            marriagePaint,
          );
          canvas.drawLine(
            Offset(startX, midY + 2.5),
            Offset(endX, midY + 2.5),
            marriagePaint,
          );
        }
      }
    }

    // 2. Draw parent-child connector lines
    for (int genIndex = 0; genIndex < generations.length - 1; genIndex++) {
      final currentGen = generations[genIndex];
      final nextGen = generations[genIndex + 1];

      final processedParents = <String>{};

      for (final person in currentGen) {
        if (processedParents.contains(person.id)) continue;

        Person? spouse;
        if (person.spouseId != null) {
          for (final p in currentGen) {
            if (p.id != person.id &&
                (p.id == person.spouseId || (p.mid != null && p.mid == person.spouseId))) {
              spouse = p;
              break;
            }
          }
        }

        processedParents.add(person.id);
        if (spouse != null) {
          processedParents.add(spouse.id);
        }

        final pRect = cardPositions[person.id];
        if (pRect == null) continue;

        Offset sourcePos;
        if (spouse != null && cardPositions.containsKey(spouse.id)) {
          final sRect = cardPositions[spouse.id]!;
          sourcePos = Offset(
            (pRect.center.dx + sRect.center.dx) / 2,
            math.max(pRect.bottom, sRect.bottom),
          );
        } else {
          sourcePos = Offset(pRect.center.dx, pRect.bottom);
        }

        // Find children of this parent / couple in nextGen
        final children = nextGen.where((c) {
          final mP1 = (person.mid != null && c.parentIds.contains(person.mid)) ||
              c.parentIds.contains(person.id);
          final mP2 = spouse != null &&
              (((spouse.mid != null && c.parentIds.contains(spouse.mid))) ||
                  c.parentIds.contains(spouse.id));
          if (mP1 || mP2) return true;

          final cP1 = (c.mid != null && person.childrenIds.contains(c.mid)) ||
              person.childrenIds.contains(c.id);
          final cP2 = spouse != null &&
              (((c.mid != null && spouse.childrenIds.contains(c.mid))) ||
                  spouse.childrenIds.contains(c.id));
          if (cP1 || cP2) return true;

          // Fallback for Gen 0 when parentIds are empty in Firestore
          if (genIndex == 0 && c.parentIds.isEmpty) {
            final rel = (c.relationToHead ?? '').toLowerCase();
            if (rel == 'son' || rel == 'daughter' || rel.isEmpty) return true;
          }
          return false;
        }).toList();

        if (children.isEmpty) continue;

        // Get target points (top of each child card)
        final List<Offset> childTargets = [];
        for (final child in children) {
          final cRect = cardPositions[child.id];
          if (cRect != null) {
            childTargets.add(Offset(cRect.center.dx, cRect.top));
          }
        }

        if (childTargets.isEmpty) continue;

        // Calculate bus bar Y level (halfway between bottom of parent and top of children)
        final minChildTop = childTargets.map((t) => t.dy).reduce(math.min);
        final busY = (sourcePos.dy + minChildTop) / 2;

        if (childTargets.length == 1) {
          final target = childTargets.first;
          // Vertical drop from parent to busY
          canvas.drawLine(sourcePos, Offset(sourcePos.dx, busY), treePaint);
          // Horizontal to target X
          if ((sourcePos.dx - target.dx).abs() > 1.0) {
            canvas.drawLine(Offset(sourcePos.dx, busY), Offset(target.dx, busY), treePaint);
          }
          // Vertical drop down to child
          canvas.drawLine(Offset(target.dx, busY), target, treePaint);
        } else {
          final minX = childTargets.map((t) => t.dx).reduce(math.min);
          final maxX = childTargets.map((t) => t.dx).reduce(math.max);
          final busLeft = math.min(sourcePos.dx, minX);
          final busRight = math.max(sourcePos.dx, maxX);

          // Vertical drop from parent to busY
          canvas.drawLine(sourcePos, Offset(sourcePos.dx, busY), treePaint);

          // Horizontal bus bar
          canvas.drawLine(Offset(busLeft, busY), Offset(busRight, busY), treePaint);

          // Vertical drops to each child
          for (final target in childTargets) {
            canvas.drawLine(Offset(target.dx, busY), target, treePaint);
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
