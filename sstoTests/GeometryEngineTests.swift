import Testing
import SceneKit
@testable import ssto

struct GeometryEngineTests {

    @Test func testGeometryGeneration() {
        // Given
        let planform = TopViewPlanform.defaultPlanform
        let profile = SideProfileShape.defaultProfile
        let crossSection = CrossSectionPoints.defaultPoints
        
        GameManager.shared.setTopViewPlanform(planform)
        GameManager.shared.setSideProfile(profile)
        GameManager.shared.setCrossSectionPoints(crossSection)
        
        // When
        let geometry = LiftingBodyEngine.generateGeometry()
        
        // Then
        let vertexSource = geometry.sources(for: .vertex).first
        #expect(vertexSource != nil, "Geometry should have vertices")
        
        let element = geometry.elements.first
        #expect(element != nil, "Geometry should have elements (triangles)")
        
        if let source = vertexSource {
            #expect(source.vectorCount > 100, "Geometry should have a reasonable number of vertices")
        }
    }
    
    @Test func testCanvasToMetersScaling() {
        // Verify that 70m length results in vertices roughly 70m long
        var planform = TopViewPlanform.defaultPlanform
        planform.aircraftLength = 70.0
        
        GameManager.shared.setTopViewPlanform(planform)
        
        let geometry = LiftingBodyEngine.generateGeometry()
        
        let minVec = geometry.boundingBox.min
        let maxVec = geometry.boundingBox.max
        let length = maxVec.x - minVec.x
        
        // Allow some tolerance (vertices are sampled, so might not hit exactly 0.0 and 70.0)
        #expect(length > 68.0 && length < 72.0, "Geometry length should match aircraftLength (70m), got \(length)")
    }
}
