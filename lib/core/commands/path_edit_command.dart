import '../geometry/path_data.dart';
import '../model/document.dart';
import '../model/node.dart';
import 'commands.dart';

/// Command that updates a path's geometry by replacing its [PathData].
class UpdatePathGeometryCommand extends Command {
  UpdatePathGeometryCommand(this.nodeId, this.before, this.after, {this.mergeKey});

  final String nodeId;
  final PathData before;
  final PathData after;
  final Object? mergeKey;

  @override
  String get label => 'Edit Path Node';

  @override
  Document apply(Document doc) {
    return doc.updateNode(nodeId, (node) {
      if (node is PathNode) {
        return node.copyWith(path: after);
      }
      return node;
    });
  }

  @override
  Document revert(Document doc) {
    return doc.updateNode(nodeId, (node) {
      if (node is PathNode) {
        return node.copyWith(path: before);
      }
      return node;
    });
  }

  @override
  Command? mergeWith(Command next) {
    if (mergeKey != null &&
        next is UpdatePathGeometryCommand &&
        next.mergeKey == mergeKey &&
        next.nodeId == nodeId) {
      return UpdatePathGeometryCommand(nodeId, before, next.after, mergeKey: mergeKey);
    }
    return null;
  }
}
