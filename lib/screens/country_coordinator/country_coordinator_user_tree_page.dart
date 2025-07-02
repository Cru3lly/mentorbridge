import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:graphview/graphview.dart';

class CountryCoordinatorUserTreePage extends StatefulWidget {
  const CountryCoordinatorUserTreePage({super.key});

  @override
  State<CountryCoordinatorUserTreePage> createState() =>
      _CountryCoordinatorUserTreePageState();
}

class _CountryCoordinatorUserTreePageState
    extends State<CountryCoordinatorUserTreePage> {
  final Graph graph = Graph();
  final Set<String> _nodeIds = {};
  final Map<String, Map<String, dynamic>> _userCache = {};
  late BuchheimWalkerAlgorithm algorithm;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  Map<String, dynamic>? currentUserData;

  @override
  void initState() {
    super.initState();
    final builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = (100)
      ..levelSeparation = (100)
      ..subtreeSeparation = (100)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);

    algorithm = BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder));

    _initializeGraph();
  }

  String _formatRoleName(String role) {
    if (role.isEmpty) return 'N/A';
    // Add space before capital letters, then capitalize the first letter of the resulting string.
    var formatted =
        role.replaceAllMapped(RegExp(r'(?<!^)[A-Z]'), (match) => ' ${match[0]}');
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  Future<void> _initializeGraph() async {
    await _fetchCurrentUser();
    if (currentUserData != null) {
      _userCache[currentUserId] = currentUserData!;
      final userNode = Node.Id(currentUserId);
      if (_nodeIds.add(currentUserId)) {
        graph.addNode(userNode);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchChildrenAndAddNodes(Node parentNode) async {
    final parentId = parentNode.key?.value as String;

    final parentData = _userCache[parentId];
    if (parentData == null) {
      // Parent data should be in the cache if the node exists.
      // Fetching it just in case of an unexpected scenario.
      final parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentId)
          .get();
      if (!parentDoc.exists) return;
      _userCache[parentId] = {'id': parentId, ...parentDoc.data()!};
    }

    final parentRole = _userCache[parentId]!['role'] as String?;
    QuerySnapshot<Map<String, dynamic>> childrenSnapshot;

    if (parentRole == 'mentor') {
      final assignedTo =
          List<String>.from(_userCache[parentId]!['assignedTo'] ?? []);
      if (assignedTo.isEmpty) return;

      // Note: Firestore 'whereIn' queries are limited to 30 items.
      final Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: assignedTo);
      childrenSnapshot = await query.get();
    } else {
      Query<Map<String, dynamic>> childrenQuery = FirebaseFirestore.instance
          .collection('users')
          .where('parentId', isEqualTo: parentId);

      if (parentRole != null && parentRole.contains('UnitCoordinator')) {
        childrenQuery = childrenQuery.where('role', isEqualTo: 'mentor');
      }

      childrenSnapshot = await childrenQuery.get();
    }

    for (var doc in childrenSnapshot.docs) {
      final childId = doc.id;
      final childData = doc.data();
      _userCache[childId] = {'id': childId, ...childData};

      final childNode = Node.Id(childId);
      if (_nodeIds.add(childId)) {
        graph.addNode(childNode);
      }
      graph.addEdge(parentNode, childNode);
    }
  }

  Future<void> _fetchCurrentUser() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      currentUserData = {'id': doc.id, ...doc.data()!};
    }
  }

  void _collapseNode(Node node) {
    final children = graph.successorsOf(node).toList();
    for (final child in children) {
      _collapseNode(child); // Recursively collapse children
      graph.removeNode(child);
      _nodeIds.remove(child.key?.value);
      _userCache.remove(child.key?.value);
    }
  }

  Future<void> _onNodeTap(Node node) async {
    if (graph.successorsOf(node).isNotEmpty) {
      _collapseNode(node);
    } else {
      await _fetchChildrenAndAddNodes(node);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'countryCoordinator':
        return const Color(0xFFD1C4E9); // Light Purple
      case 'highSchoolRegionCoordinator':
      case 'middleSchoolRegionCoordinator':
      case 'universityRegionCoordinator':
        return const Color(0xFFC5CAE9); // Light Indigo
      case 'highSchoolUnitCoordinator':
      case 'middleSchoolUnitCoordinator':
      case 'universityUnitCoordinator':
        return const Color(0xFFB2DFDB); // Light Teal
      case 'mentor':
        return const Color(0xFFFFECB3); // Light Amber
      case 'student':
      case 'mentee':
        return const Color(0xFFF8BBD0); // Light Pink
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Relationship Map'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: currentUserData == null
              ? const Center(child: CircularProgressIndicator())
              : InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(200),
                  minScale: 0.1,
                  maxScale: 2.0,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: screenSize.width,
                      minHeight: screenSize.height,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80.0),
                        child: GraphView(
                          graph: graph,
                          algorithm: algorithm,
                          paint: Paint()
                            ..color = Colors.white
                            ..strokeWidth = 2
                            ..style = PaintingStyle.stroke,
                          builder: (Node node) {
                            return _buildNodeWidget(node);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNodeWidget(Node node) {
    final nodeId = node.key?.value as String;
    final userData = _userCache[nodeId];

    if (userData == null) {
      // This might happen briefly if the data isn't cached yet.
      // A placeholder or loading indicator is appropriate.
      return const SizedBox(
        width: 150,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final name =
        "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim();
    final role = userData['role'] ?? 'N/A';
    final formattedRole = _formatRoleName(role);

    return InkWell(
      onTap: () => _onNodeTap(node),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: _getRoleColor(role),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name.isEmpty ? nodeId : name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              formattedRole,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
} 