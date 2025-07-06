# Mind Map Performance & Data Consistency Specification

**Version:** 1.0  
**Date:** July 6, 2025  
**Sprint:** 6 - The Connected Brain - Intelligent Mind Map  

---

## Overview

This document outlines the technical requirements for mind map performance optimization and data consistency management, ensuring the mind map visualization remains responsive and accurate even with large datasets and frequent data changes.

## Performance Requirements

### Layout Calculation Optimization

#### Primary Rule: Cache-First Approach
- **Mind map layout positions MUST be cached** and only recalculated when underlying data changes
- **Cache persistence:** Layout state saved to SwiftData and restored across app sessions
- **Target load time:** <200ms to restore cached mind map layout from persistence

#### Change Detection System
- **Data fingerprinting:** Generate checksums for screenshot collections and relationship data
- **Incremental detection:** Compare current data state against cached fingerprint
- **Selective invalidation:** Only invalidate cache for affected nodes and relationships

#### Localized Recalculation
- **Single node changes:** <100ms processing time for adding/removing one screenshot
- **Regional updates:** <500ms for changes affecting up to 20 connected nodes
- **Incremental layout:** Only recalculate positions for nodes within 2-degree separation from changes

### Performance Benchmarks

| Operation | Target Time | Measurement Method |
|-----------|-------------|-------------------|
| Initial layout generation (100 screenshots) | <5 seconds | Cold start with no cache |
| Layout cache restoration | <200ms | App launch with existing cache |
| Single node addition | <100ms | Add one screenshot to existing map |
| Single node deletion | <100ms | Remove one screenshot and cleanup |
| Regional update (20 nodes) | <500ms | AI re-analysis affecting cluster |
| Cache hit rate | >90% | Percentage of cached position reuse |
| Memory footprint | <200MB | Peak memory during layout calculation |

## Data Consistency Management

### Edge Case Scenarios

#### 1. Screenshot Deletion
**Problem:** User or system deletes screenshot that exists in mind map

**Solution:**
- **Automatic cleanup:** Remove node and all connected relationships
- **Layout adjustment:** Recalculate only immediate neighbors (1-degree separation)
- **Orphan prevention:** Ensure no dangling relationship references remain
- **Undo support:** Preserve deleted node data for potential restoration

**Implementation:**
```swift
func handleScreenshotDeletion(screenshotId: UUID) {
    // 1. Identify connected nodes
    let connectedNodes = mindMapData.getConnectedNodes(for: screenshotId)
    
    // 2. Remove node and relationships
    mindMapData.removeNode(id: screenshotId)
    
    // 3. Localized layout recalculation
    layoutEngine.recalculateRegion(nodeIds: connectedNodes.map(\.id))
    
    // 4. Update cache
    layoutCache.invalidateNodes(connectedNodes.map(\.id))
}
```

#### 2. AI Analysis Updates
**Problem:** AI re-analysis changes relationship data for existing screenshots

**Solution:**
- **Version tracking:** Track AI analysis version for each screenshot
- **Diff-based updates:** Compare new vs. old relationship data
- **Incremental application:** Only update changed relationships
- **Conflict resolution:** Handle conflicts between user edits and AI updates

**Implementation:**
```swift
func handleAIAnalysisUpdate(screenshotId: UUID, newRelationships: [Relationship]) {
    // 1. Compare with existing relationships
    let currentRelationships = relationshipService.getRelationships(for: screenshotId)
    let diff = calculateRelationshipDiff(current: currentRelationships, new: newRelationships)
    
    // 2. Apply only changes
    applyRelationshipChanges(diff)
    
    // 3. Localized layout update
    let affectedNodeIds = diff.affectedNodes
    layoutEngine.recalculateRegion(nodeIds: affectedNodeIds)
}
```

#### 3. User Annotation Changes
**Problem:** User manually edits screenshot annotations, potentially affecting relationships

**Solution:**
- **Change tracking:** Monitor user annotation modifications
- **Impact assessment:** Determine if changes affect existing relationships
- **Minimal recalculation:** Only update layout if relationship structure changes
- **Priority preservation:** User edits take precedence over AI suggestions

#### 4. Concurrent Modifications
**Problem:** Multiple processes (user edits, AI updates, background processing) modify data simultaneously

**Solution:**
- **Atomic operations:** Use database transactions for all data modifications
- **Conflict detection:** Compare modification timestamps
- **Resolution strategy:** User edits > Manual relationships > AI relationships
- **Rollback capability:** Ability to revert to last known good state

### Data Versioning System

#### Change Tracking
```swift
struct DataVersion {
    let timestamp: Date
    let versionId: UUID
    let changeType: ChangeType
    let affectedNodes: [UUID]
    let checksum: String
}

enum ChangeType {
    case screenshotAdded(UUID)
    case screenshotDeleted(UUID)
    case screenshotModified(UUID)
    case relationshipAdded(UUID, UUID)
    case relationshipDeleted(UUID, UUID)
    case userAnnotationChanged(UUID)
    case aiAnalysisUpdated(UUID)
}
```

#### Conflict Resolution Priority
1. **User manual edits** (highest priority)
2. **Manual relationship creation/deletion**
3. **User annotations and tags**
4. **AI-generated relationships**
5. **Automatic semantic analysis** (lowest priority)

## Caching Strategy

### Layout Cache Architecture

#### Cache Levels
1. **Memory Cache:** In-memory positions for current session
2. **Disk Cache:** SwiftData persistence for layout positions
3. **Relationship Cache:** Cached relationship calculations
4. **Viewport Cache:** Cached visible node calculations

#### Cache Invalidation Rules
- **Screenshot added/deleted:** Invalidate affected region (2-degree separation)
- **Relationship changed:** Invalidate connected nodes
- **User manual positioning:** Invalidate specific node only
- **Global recalculation:** Clear entire cache (rare, only for major changes)

#### Cache Performance Targets
- **Hit rate:** >90% for typical usage patterns
- **Memory usage:** <50MB for layout cache
- **Persistence time:** <100ms to save layout state
- **Restoration time:** <200ms to load cached layout

## Implementation Architecture

### Core Services

#### LayoutCacheManager
```swift
@MainActor
class LayoutCacheManager: ObservableObject {
    func getCachedLayout(for dataFingerprint: String) -> MindMapLayout?
    func saveLayout(_ layout: MindMapLayout, fingerprint: String)
    func invalidateRegion(nodeIds: [UUID])
    func invalidateAll()
}
```

#### DataConsistencyManager
```swift
@MainActor
class DataConsistencyManager: ObservableObject {
    func handleDataChange(_ change: DataChange) async
    func resolveConflicts(_ conflicts: [DataConflict]) -> Resolution
    func validateDataIntegrity() -> ValidationResult
}
```

#### ChangeTrackingService
```swift
class ChangeTrackingService {
    func trackChange(_ change: DataChange)
    func getChangesSince(_ version: DataVersion) -> [DataChange]
    func createDataFingerprint(screenshots: [Screenshot], relationships: [Relationship]) -> String
}
```

### Performance Monitoring

#### Metrics Collection
- Layout calculation times
- Cache hit/miss rates
- Memory usage patterns
- Change propagation times
- User interaction response times

#### Performance Alerts
- Layout calculation >5 seconds
- Cache hit rate <80%
- Memory usage >250MB
- Incremental update >1 second

## Testing Strategy

### Performance Tests
1. **Load testing:** 1000+ screenshots with complex relationships
2. **Incremental update testing:** Rapid add/delete operations
3. **Cache effectiveness:** Measure hit rates under various usage patterns
4. **Memory stress testing:** Large datasets with limited memory

### Edge Case Tests
1. **Rapid deletion:** Delete multiple connected screenshots quickly
2. **Concurrent modification:** Simultaneous user/AI changes
3. **Data corruption:** Recovery from corrupted cache data
4. **Network interruption:** Handle incomplete AI analysis updates

### Consistency Tests
1. **Relationship integrity:** Ensure no orphaned connections
2. **Layout consistency:** Verify positions remain stable across sessions
3. **Version conflicts:** Test resolution of competing changes
4. **Rollback scenarios:** Verify undo functionality works correctly

## Success Criteria

### Performance Criteria (Must Meet)
- ✅ Layout cache restoration: <200ms
- ✅ Single node updates: <100ms
- ✅ Regional updates (20 nodes): <500ms
- ✅ Cache hit rate: >90%
- ✅ Memory usage: <200MB peak

### Consistency Criteria (Must Meet)
- ✅ Zero orphaned relationships after deletion
- ✅ Conflict resolution maintains user priority
- ✅ Layout state persists across app sessions
- ✅ Incremental updates preserve existing positioning
- ✅ Data corruption auto-recovery functional

### User Experience Criteria (Must Meet)
- ✅ No full mind map regeneration during normal usage
- ✅ Smooth transitions during incremental updates
- ✅ Immediate response to user positioning changes
- ✅ No data loss during concurrent modifications
- ✅ Intuitive conflict resolution without user intervention

---

This specification ensures the mind map feature scales efficiently with large datasets while maintaining data consistency and providing a smooth user experience even during complex data modification scenarios.
