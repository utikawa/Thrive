--------------------------------------------------------------------------------
-- MicrobeAIComponent
--
-- Component for identifying and determining AI controlled microbes.
--------------------------------------------------------------------------------
class 'MicrobeAIComponent' (Component)

OXYGEN_SEARCH_THRESHHOLD = 8
GLUCOSE_SEARCH_THRESHHOLD = 5
AI_MOVEMENT_SPEED = 1

function MicrobeAIComponent:__init()
    Component.__init(self)
    self.movementRadius = 20
    self.reevalutationInterval = 1000
    self.intervalRemaining = self.reevalutationInterval
    self.direction = Vector3(0, 0, 0)
    self.initialized = false
    self.targetEmitterPosition = nil
    self.searchedAgentId = nil
end


function MicrobeAIComponent:load(storage)
    Component.load(self, storage)

end


function MicrobeAIComponent:storage()
    local storage = Component.storage(self)

end

REGISTER_COMPONENT("MicrobeAIComponent", MicrobeAIComponent)


--------------------------------------------------------------------------------
-- MicrobeAISystem
--
-- Updates AI controlled microbes
--------------------------------------------------------------------------------

class 'MicrobeAISystem' (System)

function MicrobeAISystem:__init()
    System.__init(self)
    self.entities = EntityFilter(
        {
            MicrobeAIComponent,
            MicrobeComponent
        }, 
        true
    )
    self.emitters = EntityFilter(
        {
            AgentEmitterComponent
        }, 
        true
    )
    self.microbes = {}
    self.oxygenEmitters = {}
    self.glucoseEmitters = {}
end


function MicrobeAISystem:init(gameState)
    System.init(self, gameState)
    self.entities:init(gameState)
    self.emitters:init(gameState)
end


function MicrobeAISystem:shutdown()
    self.entities:shutdown()
    self.emitters:shutdown()
end


function MicrobeAISystem:update(milliseconds)
    for entityId in self.entities:removedEntities() do
        self.microbes[entityId] = nil
    end
    for entityId in self.entities:addedEntities() do
        local microbe = Microbe(Entity(entityId))
        self.microbes[entityId] = microbe
    end
    
    for entityId in self.emitters:removedEntities() do
        self.oxygenEmitters[entityId] = nil
        self.glucoseEmitters[entityId] = nil
    end
    for entityId in self.emitters:addedEntities() do
        local emitterComponent = Entity(entityId):getComponent(AgentEmitterComponent.TYPE_ID)
        if emitterComponent.agentId == AgentRegistry.getAgentId("oxygen") then
            self.oxygenEmitters[entityId] = true
        elseif emitterComponent.agentId == AgentRegistry.getAgentId("glucose") then
            self.glucoseEmitters[entityId] = true
        end
        self.microbes[entityId] = microbe
    end
    self.entities:clearChanges()
    self.emitters:clearChanges()
    for _, microbe in pairs(self.microbes) do
        local aiComponent = microbe.aiController
        aiComponent.intervalRemaining = aiComponent.intervalRemaining + milliseconds
        while aiComponent.intervalRemaining > aiComponent.reevalutationInterval do
            aiComponent.intervalRemaining = aiComponent.intervalRemaining - aiComponent.reevalutationInterval
            
            local targetPosition = nil
            if microbe:getAgentAmount(AgentRegistry.getAgentId("oxygen")) <= OXYGEN_SEARCH_THRESHHOLD then
                 print("need oxygen!")
                -- If we are NOT currenty heading towards an emitter
                if aiComponent.targetEmitterPosition == nil or aiComponent.searchedAgentId ~= AgentRegistry.getAgentId("oxygen") then
                    print("finding emitter")
                    aiComponent.searchedAgentId = AgentRegistry.getAgentId("oxygen")
                    for emitterId, _ in pairs(self.oxygenEmitters) do
                        aiComponent.targetEmitterPosition = Entity(emitterId):getComponent(OgreSceneNodeComponent.TYPE_ID).transform.position
                        break -- We only get the first element
                    end      
                end
                targetPosition = aiComponent.targetEmitterPosition           
                if aiComponent.targetEmitterPosition ~= nil and aiComponent.targetEmitterPosition.z ~= 0 then
                    aiComponent.targetEmitterPosition = nil
                end             
            elseif microbe:getAgentAmount(AgentRegistry.getAgentId("glucose")) <= GLUCOSE_SEARCH_THRESHHOLD then
            print("need glucose!")
                -- If we are NOT currenty heading towards an emitter
                if aiComponent.targetEmitterPosition == nil or aiComponent.searchedAgentId ~= AgentRegistry.getAgentId("glucose") then
                aiComponent.searchedAgentId = AgentRegistry.getAgentId("glucose")
                print("finding glucose")
                    for emitterId, _ in pairs(self.glucoseEmitters) do
                        aiComponent.targetEmitterPosition = Entity(emitterId):getComponent(OgreSceneNodeComponent.TYPE_ID).transform.position
                        break
                    end  
                end
                targetPosition = aiComponent.targetEmitterPosition
                if aiComponent.targetEmitterPosition ~= nil and aiComponent.targetEmitterPosition.z ~= 0 then
                 print("oups 2")
                    aiComponent.targetEmitterPosition = nil
                end    
            else
                aiComponent.targetEmitterPosition = nil
            end
            if aiComponent.targetEmitterPosition == nil then
                 print("wandering")
                local randAngle = rng:getReal(0, 2*math.pi)
                local randDist = rng:getInt(10, aiComponent.movementRadius)
                targetPosition = Vector3(math.cos(randAngle)* randDist, 
                                         math.sin(randAngle)* randDist, 0)
            end
           -- print("IS AT: ")
        --    print(microbe.sceneNode.transform.position)
          --  print("heading towards: ")
         --   print(targetPosition)
            local vec = (targetPosition - microbe.sceneNode.transform.position)
            vec:normalise()
            --print("VEC LENGTH: " .. vec:length())

            print("setting target position: ") print(targetPosition)
            aiComponent.direction = vec--Vector3(vec.x * AI_MOVEMENT_SPEED, vec.y * AI_MOVEMENT_SPEED, 0)   
            microbe.microbe.facingTargetPoint = targetPosition -- aiComponent.direction--Vector3(0,0,0) - targetPosition
            microbe.microbe.movementDirection = Vector3(0,0.5,0)--aiComponent.direction 
            
        end
        --print(aiComponent.direction)

        
    end
end
