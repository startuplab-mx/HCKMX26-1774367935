import SwiftUI
import SpriteKit

struct HomeView: View {
    // MARK: - State

    @State private var pet: Pet
    @State private var service: PetService
    @State private var personality: PersonalityTracker = .load()
    @State private var coins: Int = CoinWallet.balance
    @State private var caretakerLevel: Int = ProgressionService.level
    @AppStorage("buddy.dynamicIsland") private var dynamicIslandOn = true
    @AppStorage("buddy.sounds") private var soundsOn = true
    @State private var sceneTheme: SceneTheme = SceneStore.active
    @State private var equippedAccessory: String? = InventoryStore.equippedAccessoryEmoji
    @State private var toast = ToastQueue.shared

    // Onboarding
    @AppStorage("buddy.onboarded") private var didOnboard = false

    // Sheets
    @State private var showStats = false
    @State private var showPets = false
    @State private var showScenes = false
    @State private var showSettings = false
    @State private var showShop = false
    @State private var showAchievements = false
    @State private var showMinigamesHub = false
    @State private var activeMinigame: MinigameID?
    @State private var showShare = false
    @State private var showDiary = false
    @State private var showPhoto = false

    // Random event timer
    @State private var eventTask: Task<Void, Never>?

    // SpriteKit scene
    private let scene: BuddyScene = {
        let s = BuddyScene()
        s.scaleMode = .aspectFill
        return s
    }()

    init() {
        let loaded = PetStore.load() ?? Pet()
        _pet = State(initialValue: loaded)
        _service = State(initialValue: PetService(pet: loaded))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Theme.consoleBG.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                sceneArea
                LCDCard(pet: pet)
                    .padding(.top, 16)
                    .onTapGesture { showStats = true }
                dynamicIslandRow.padding(.top, 8)
                bottomActionsRow.padding(.top, 6)
                controlsRow.padding(.top, 4)
                Spacer(minLength: 0)
                shimejiTag.padding(.bottom, 12)
            }

            // Toast overlay
            if let t = toast.current {
                VStack {
                    Spacer().frame(height: 60)
                    ToastBanner(emoji: t.emoji, title: t.title, detail: t.detail)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: t.id)
            }
        }
        .onAppear(perform: onAppear)
        .onDisappear { eventTask?.cancel() }
        .onChange(of: dynamicIslandOn, onDIToggle)
        .onChange(of: pet.currentAction, onActionChange)
        .onChange(of: pet.stats.hunger)    { _, _ in service.recomputeNeeds(); persist() }
        .onChange(of: pet.stats.thirst)    { _, _ in service.recomputeNeeds(); persist() }
        .onChange(of: pet.stats.energy)    { _, _ in service.recomputeNeeds(); persist() }
        .onChange(of: pet.stats.hygiene)   { _, _ in service.recomputeNeeds(); persist() }
        .onChange(of: pet.stats.happiness) { _, _ in service.recomputeNeeds(); persist() }
        .onChange(of: service.needs)       { _, _ in updateBubble(); rescheduleNotifications() }
        .fullScreenCover(isPresented: .constant(!didOnboard)) {
            OnboardingView { name, character in
                pet.name = name.isEmpty ? "Buddy" : name
                pet.character = character
                didOnboard = true
                persist()
                Task { await NotificationService.shared.requestPermission() }
            }
        }
        .sheet(isPresented: $showStats)    { StatsSheet(pet: pet, needs: service.needs) { showStats = false }.presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showPets)     {
            PetsSheet(current: pet.character, coins: coins, onPick: changeCharacter, onUnlock: unlockCharacter) { showPets = false }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showScenes)   {
            ScenesSheet(current: sceneTheme, coins: coins, onPick: changeScene, onUnlock: unlockScene) { showScenes = false }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(dynamicIslandOn: $dynamicIslandOn, soundsOn: $soundsOn, onResetPet: resetPet) { showSettings = false }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showShop) {
            ShopSheet(coins: coins, onBuy: buyItem, onConsume: consumeItem, onEquip: equipItem) { showShop = false }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAchievements) {
            AchievementsSheet { showAchievements = false }.presentationDetents([.large])
        }
        .sheet(isPresented: $showMinigamesHub) {
            MinigamesHubSheet(onPick: { game in showMinigamesHub = false; activeMinigame = game }) { showMinigamesHub = false }
                .presentationDetents([.medium])
        }
        .fullScreenCover(item: $activeMinigame) { game in
            minigameView(for: game)
        }
        .sheet(isPresented: $showShare)  { ShareCaretakerSheet { showShare = false }.presentationDetents([.large]) }
        .sheet(isPresented: $showDiary)  { DiarySheet { showDiary = false }.presentationDetents([.large]) }
        .sheet(isPresented: $showPhoto)  { PhotoModeSheet(pet: pet) { showPhoto = false }.presentationDetents([.large]) }
        .sheet(isPresented: .constant(service.isDead)) {
            ReincarnationSheet { name, character in
                service.reincarnate(name: name, character: character)
                personality = PersonalityTracker()
                personality.save()
                PersonalityTracker.reset()
                AchievementUnlocker.reincarnation()
                persist()
            }
        }
    }

    // MARK: - Scene area

    private var sceneArea: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .overlay(
                    Color(red: sceneTheme.tintColor.r, green: sceneTheme.tintColor.g, blue: sceneTheme.tintColor.b)
                        .opacity(sceneTheme.tintColor.a)
                )
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .ignoresSafeArea(edges: .top)
            TopBar(
                coins: coins,
                lives: caretakerLevel,
                onInfo: { showStats = true },
                onSettings: { showSettings = true }
            )
            .padding(.top, 8)
        }
        .frame(height: 480)
        .padding(.horizontal, 8)
    }

    // MARK: - Dynamic island row

    private var dynamicIslandRow: some View {
        HStack {
            Text("Dynamic island")
                .font(.custom(Theme.pixelMono, size: 16).weight(.bold))
                .foregroundStyle(Theme.darkInk)
            if personality.derivedTrait != .neutral {
                Text("· \(personality.derivedTrait.emoji) \(personality.derivedTrait.label)")
                    .font(.custom(Theme.pixelMono, size: 11))
                    .foregroundStyle(Theme.darkInk.opacity(0.6))
            }
            let stage = EvolutionStage.stage(forAgeDays: pet.ageInDays)
            Text("· \(stage.emoji) \(stage.label)")
                .font(.custom(Theme.pixelMono, size: 11))
                .foregroundStyle(Theme.darkInk.opacity(0.6))
            Spacer()
            Toggle("", isOn: $dynamicIslandOn).labelsHidden().tint(Theme.actionPink)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Bottom actions row (Pets, Scenes, Shop, Minigames, Achievements)

    private var bottomActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                navPill("🐱", "Pets") { showPets = true }
                navPill("🏠", "Scenes") { showScenes = true }
                navPill("🛒", "Tienda") { showShop = true }
                navPill("🎮", "Juegos") { showMinigamesHub = true }
                navPill("🏆", "Logros") { showAchievements = true }
                navPill("📖", "Diario") { showDiary = true }
                navPill("📸", "Foto") { showPhoto = true }
                navPill("👥", "Compartir") { showShare = true }
            }
            .padding(.horizontal, 24)
        }
    }

    private func navPill(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button {
            SoundService.shared.playClick()
            action()
        } label: {
            HStack(spacing: 4) {
                Text(icon).font(.system(size: 14))
                Text(title).font(.custom(Theme.pixelMono, size: 12))
                    .foregroundStyle(Theme.darkInk)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.buttonBG)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.buttonStroke.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controls (joystick + contextual + sleep)

    private var controlsRow: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                xpBar
            }
            Spacer()
            ZStack {
                JoystickView { v in scene.setPlayerVelocity(v) }
                    .offset(x: -90, y: 12)
                contextualButton.offset(x: 60, y: -16)
                ActionButton(label: "💤", size: 62) {
                    SoundService.shared.playClick()
                    service.sleep()
                    scene.sleepAnimation()
                    afterAction(.sleep)
                }
                .offset(x: 0, y: 36)
            }
            .frame(width: 180, height: 140)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    /// Caretaker XP bar.
    private var xpBar: some View {
        let xpInLvl = ProgressionService.xpInCurrentLevel
        let xpForNext = ProgressionService.xpForNextLevel
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Cuidador Lv \(caretakerLevel)").font(.custom(Theme.pixelMono, size: 11).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                Spacer()
                Text("\(xpInLvl)/\(xpForNext) XP").font(.custom(Theme.pixelMono, size: 9))
                    .foregroundStyle(Theme.darkInk.opacity(0.5))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.darkInk.opacity(0.1))
                    Capsule().fill(Theme.actionPink)
                        .frame(width: max(4, geo.size.width * CGFloat(xpInLvl) / CGFloat(max(1, xpForNext))))
                }
            }
            .frame(height: 6)
        }
        .frame(width: 150)
    }

    private var contextualButton: some View {
        let topNeed = service.needs.first
        let label = topNeed?.actionLabel ?? "Acariciar"
        return Button {
            handleContextualAction(topNeed)
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(Theme.actionPink)
                    .overlay(Circle().stroke(Theme.actionPinkDark, lineWidth: 3))
                    .frame(width: 62, height: 62)
                    .overlay(Text(topNeed?.emoji ?? "🤝").font(.system(size: 24)))
                Text(label)
                    .font(.custom(Theme.pixelMono, size: 10).weight(.bold))
                    .foregroundStyle(Theme.darkInk)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var shimejiTag: some View {
        Text("Buddy")
            .font(.custom(Theme.pixelMono, size: 11).italic())
            .foregroundStyle(Theme.buttonStroke)
            .padding(.horizontal, 18)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white).overlay(Capsule().stroke(Theme.buttonStroke.opacity(0.5), lineWidth: 1)))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Minigame routing

    @ViewBuilder
    private func minigameView(for game: MinigameID) -> some View {
        switch game {
        case .catchFood:
            CatchFoodGame(petName: pet.name) { earned in
                rewardFromMinigame(earned, id: .catchFood)
                // Real bonus: jugar atrapando comida también alimenta al pet
                if earned > 5 { service.feed() }
            }
        case .memoryMatch:
            MemoryMatchGame(petName: pet.name) { earned in
                rewardFromMinigame(earned, id: .memoryMatch)
                // Real bonus: usar la mente con el pet aumenta felicidad
                if earned > 0 { service.playWith() }
            }
        case .tapReaction:
            TapReactionGame(petName: pet.name) { earned in
                rewardFromMinigame(earned, id: .tapReaction)
                if earned > 0 { service.playWith() }
            }
        case .rhythmTap:
            RhythmTapGame(petName: pet.name) { earned in
                rewardFromMinigame(earned, id: .rhythmTap)
                if earned > 0 { service.playWith() }
            }
        }
    }

    private func rewardFromMinigame(_ earned: Int, id: MinigameID) {
        CoinWallet.add(earned); coins = CoinWallet.balance
        ProgressionService.addXP(earned)
        caretakerLevel = ProgressionService.level
        AchievementUnlocker.recordMinigamePlayed(id)
        AchievementUnlocker.minigamePlayed()
        DiaryStore.append(DiaryEntry(emoji: id.emoji, detail: "Jugamos a \(id.title) y ganamos \(earned)🪙"))
        activeMinigame = nil
    }

    // MARK: - Action handlers

    private func handleContextualAction(_ need: PetNeed?) {
        SoundService.shared.playClick()
        switch need {
        case .hungry:
            service.feed(); scene.feedItem(emoji: "🍖"); earn(3); afterAction(.eat)
            scene.sayPet(PetSpeech.eat()); scene.bouncePet()
        case .thirsty:
            service.giveWater(); scene.giveWaterAnimation(); earn(2); afterAction(.eat)
            scene.sayPet(PetSpeech.thirsty())
        case .sleepy:
            service.sleep(); scene.sleepAnimation(); earn(2); afterAction(.sleep)
            scene.sayPet(PetSpeech.sleep())
        case .dirty:
            service.bath(); scene.bathAnimation(); earn(3); afterAction(.idle); AchievementUnlocker.bath()
            scene.sayPet(PetSpeech.bath())
        case .bored, .none:
            service.playWith(); scene.performTrick(); earn(2); afterAction(.play)
            scene.sayPet(PetSpeech.play()); scene.emitHearts(count: 3)
        }
    }

    /// Buying a consumable charges; cosmetics auto-equip on first purchase.
    private func buyItem(_ item: ShopItem) -> Bool {
        guard CoinWallet.spend(item.price) else { return false }
        coins = CoinWallet.balance
        if item.category == .accessories || item.category == .cosmetics {
            equippedAccessory = item.emoji
            InventoryStore.equippedAccessoryID = item.id
            scene.setAccessory(emoji: item.emoji)
        }
        return true
    }

    private func consumeItem(_ item: ShopItem) {
        var s = pet.stats
        for (key, delta) in item.effects {
            switch key {
            case "hunger":    s.hunger    += delta
            case "thirst":    s.thirst    += delta
            case "energy":    s.energy    += delta
            case "hygiene":   s.hygiene   += delta
            case "happiness": s.happiness += delta
            default: break
            }
        }
        s.clamp()
        pet.stats = s
        SoundService.shared.play(for: .eat)
        // Visual: throw the food on the pet
        scene.feedItem(emoji: item.emoji)
        pet.currentAction = .eat
        ToastQueue.shared.show(emoji: item.emoji, title: item.name, detail: "Lo está disfrutando")
        DiaryStore.append(DiaryEntry(emoji: item.emoji, detail: "Le di \(item.name)"))
    }

    private func equipItem(_ item: ShopItem?) {
        if let item {
            equippedAccessory = item.emoji
            scene.setAccessory(emoji: item.emoji)
            ToastQueue.shared.show(emoji: item.emoji, title: "\(item.name) puesto", detail: "Se ve genial")
        } else {
            equippedAccessory = nil
            scene.setAccessory(emoji: nil)
            ToastQueue.shared.show(emoji: "🎀", title: "Accesorio quitado", detail: "")
        }
    }

    private func earn(_ amount: Int) {
        CoinWallet.add(amount)
        coins = CoinWallet.balance
        ProgressionService.addXP(amount * 2)
        caretakerLevel = ProgressionService.level
        SoundService.shared.playReward()
    }

    private func afterAction(_ action: PetAction) {
        personality.record(action)
        personality.save()
        AchievementUnlocker.checkAfterAction(action, pet: pet, personality: personality)
        DiaryStore.append(DiaryEntry(action: action, detail: actionDescription(action)))
        PetVoiceService.shared.say(for: action, name: pet.name)
        // Push to CloudKit (fire-and-forget, ignore errors if iCloud not set up)
        Task { try? await CloudKitService.shared.uploadPet(pet) }
    }

    private func actionDescription(_ action: PetAction) -> String {
        switch action {
        case .eat:   "Comió"
        case .play:  "Jugamos juntos"
        case .sleep: "Se durmió"
        case .sad:   "Estuvo triste"
        case .idle:  "Se relajó"
        }
    }

    private func changeCharacter(_ c: PetCharacter) {
        SoundService.shared.playClick()
        pet.character = c
        scene.setPetCharacter(asset: c.spriteSheetAsset)
        showPets = false
        persist()
    }

    private func unlockCharacter(_ c: PetCharacter) -> Bool {
        guard CoinWallet.spend(c.unlockPrice) else { return false }
        coins = CoinWallet.balance
        ToastQueue.shared.show(emoji: c.emoji, title: "\(c.displayName) desbloqueado", detail: "Tócalo para usarlo")
        return true
    }

    private func changeScene(_ s: SceneTheme) {
        SoundService.shared.playClick()
        sceneTheme = s
        SceneStore.active = s
        scene.setBackground(asset: s.assetName)
        showScenes = false
    }

    private func unlockScene(_ s: SceneTheme) -> Bool {
        guard CoinWallet.spend(s.unlockPrice) else { return false }
        coins = CoinWallet.balance
        ToastQueue.shared.show(emoji: s.emoji, title: "\(s.displayName) desbloqueado", detail: "Tócalo para usarlo")
        return true
    }

    private func resetPet() {
        let fresh = Pet()
        pet = fresh
        service = PetService(pet: fresh)
        service.start()
        PetStore.clear()
        PersonalityTracker.reset()
        personality = PersonalityTracker()
        showSettings = false
    }

    // MARK: - Lifecycle

    private func onAppear() {
        SoundService.shared.isEnabled = soundsOn
        PetVoiceService.shared.isEnabled = soundsOn
        // Apply persisted scene + character to the SpriteKit scene
        scene.setBackground(asset: sceneTheme.assetName)
        scene.setPetCharacter(asset: pet.character.spriteSheetAsset)
        service.start()

        // Habit Mirror: refleja el comportamiento del usuario en la mascota
        let mirrorMessages = HabitMirrorService.shared.applyMirror(to: pet)
        for msg in mirrorMessages {
            ToastQueue.shared.show(emoji: "🪞", title: "Espejo de hábitos", detail: msg, duration: 4)
            DiaryStore.append(DiaryEntry(emoji: "🪞", detail: msg))
        }

        // CloudKit: subscribe to remote changes from co-caretakers
        Task {
            if await CloudKitService.shared.iCloudAvailable() {
                try? await CloudKitService.shared.subscribeToChanges()
                // Try to pull latest from cloud (in case another caretaker edited)
                if let cloudPet = await CloudKitService.shared.fetchLatestPet() {
                    await MainActor.run {
                        // Only overwrite if cloud is more recent (cheap heuristic: different stats)
                        let local = pet.stats
                        let remote = cloudPet.stats
                        if local.hunger != remote.hunger || local.thirst != remote.thirst {
                            pet.stats = remote
                            pet.currentAction = cloudPet.currentAction
                            ToastQueue.shared.show(emoji: "☁️", title: "Sincronizado", detail: "Otro cuidador editó")
                        }
                    }
                }
            }
        }
        if dynamicIslandOn {
            LiveActivityManager.shared.start(pet: pet, action: pet.currentAction)
        }
        updateBubble()
        // Real interactions:
        // Single tap = caricia → +happiness
        scene.onPetTap = { [self] in
            service.pet_()
            afterAction(.play)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            scene.bouncePet()
            scene.emitHearts(count: 4)
            // Random chance to say something cute
            if Int.random(in: 0..<3) == 0 {
                scene.sayPet(PetSpeech.idle(trait: personality.derivedTrait, name: pet.name))
            }
        }
        // Double tap = trick + open stats
        scene.onPetDoubleTap = { [self] in
            scene.performTrick()
            showStats = true
        }
        // Drag-release = bonus afecto
        scene.onPetReleased = { [self] in
            pet.stats.happiness = min(100, pet.stats.happiness + 3)
            ToastQueue.shared.show(emoji: "🤗", title: "Cargaste a \(pet.name)", detail: "+3 felicidad")
        }
        // Player se acerca al pet → pet sonríe
        scene.onPlayerNearPet = { [self] in
            pet.stats.happiness = min(100, pet.stats.happiness + 1)
        }
        scene.setAccessory(emoji: equippedAccessory)

        // Daily bonus
        if let bonus = ProgressionService.claimDailyBonusIfAvailable() {
            coins = CoinWallet.balance
            let streak = ProgressionService.streak
            ToastQueue.shared.show(emoji: "🎁", title: "Bono diario · racha \(streak)", detail: "+\(bonus)🪙")
            // Confetti celebration on daily login bonus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { scene.emitConfetti() }
        }
        // Welcome speech bubble
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            scene.sayPet(PetSpeech.greeting(name: pet.name))
        }

        // Notification permission first time
        Task { await NotificationService.shared.requestPermission() }
        rescheduleNotifications()

        // Random events loop (every 90s rolls)
        eventTask?.cancel()
        eventTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(90))
                if let event = RandomEventService.maybeTrigger(pet: pet) {
                    coins = CoinWallet.balance
                    ToastQueue.shared.show(emoji: event.emoji, title: event.title, detail: event.detail)
                }
            }
        }
    }

    private func onDIToggle(_ old: Bool, _ new: Bool) {
        if new {
            LiveActivityManager.shared.start(pet: pet, action: pet.currentAction)
        } else {
            LiveActivityManager.shared.end()
        }
    }

    private func onActionChange(_ old: PetAction, _ new: PetAction) {
        SoundService.shared.play(for: new)
        LiveActivityManager.shared.update(pet: pet, action: new)
    }

    private func persist() { PetStore.save(pet) }

    private func updateBubble() { scene.showNeedBubble(emoji: service.needs.first?.emoji) }

    private func rescheduleNotifications() {
        NotificationService.shared.scheduleNeedReminders(pet: pet)
    }
}
