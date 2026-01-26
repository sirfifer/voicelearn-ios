//
//  KBHelpContent.swift
//  UnaMentis
//
//  Centralized help text for Knowledge Bowl module
//

import Foundation

// MARK: - Knowledge Bowl Help Content

/// Centralized help text for the Knowledge Bowl module
/// Organized by category for easy maintenance and consistency
enum KBHelpContent {

    // MARK: - Training Modes

    enum TrainingModes {
        // Written Round
        static let writtenOverview = """
        Practice answering multiple-choice questions against the clock. \
        In competition, written rounds test your knowledge across all domains simultaneously. \
        Work through questions systematically and don't spend too long on difficult ones.
        """

        static let writtenMCQ = """
        Select the best answer from the options provided. Tap an option to select it, \
        then tap Submit to confirm. You can change your selection before submitting.
        """

        static let writtenTimer = """
        The timer shows remaining time. Green means plenty of time, yellow means halfway, \
        and red means less than 30 seconds remain. Unanswered questions when time expires count as incorrect.
        """

        static let writtenScoring = """
        Each correct answer earns points. In written rounds, there is no penalty for guessing, \
        so always submit an answer even if you're unsure.
        """

        // Oral Round
        static let oralOverview = """
        Questions are read aloud. Use the conference time to formulate your answer \
        (or discuss with teammates in team mode), then speak your answer clearly. \
        Quick, confident answers are rewarded.
        """

        static let oralConference = """
        Conference time lets you think before answering. The rules vary by region: \
        Colorado allows only hand signals (no talking), while Minnesota and Washington \
        allow verbal discussion during conference.
        """

        static let oralVoiceInput = """
        Speak clearly and at a normal pace. The app transcribes your speech and validates \
        your answer. You'll see your transcribed text appear as you speak.
        """

        static let oralTranscript = """
        Your spoken answer is transcribed in real-time. The answer validator accepts \
        correct answers even with minor pronunciation differences or alternate phrasings.
        """

        // Match Simulation
        static let matchOverview = """
        Experience a full Knowledge Bowl match with simulated opponent teams. \
        Matches include written rounds followed by oral rounds with buzzing and rebounds. \
        This is the closest practice to actual competition.
        """

        static let matchFormat = """
        Quick Match: 5 written questions + 2 oral rounds. Great for quick practice. \
        Standard Match: 20 written questions + 5 oral rounds. Moderate length. \
        Full Match: Complete competition format matching your region's rules.
        """

        static let matchOpponents = """
        AI opponents simulate real competition. Beginner opponents answer about 40% correctly, \
        Intermediate about 60%, and Advanced about 80%. Challenge yourself as you improve!
        """

        static let matchBuzzing = """
        Only buzz if you're confident you know the answer. In oral rounds, \
        an incorrect answer gives points to opponents and may give them a rebound opportunity. \
        Wait for more of the question if you're unsure.
        """

        static let matchRebound = """
        When an opponent answers incorrectly, you get a rebound opportunity. \
        Rebounds are valuable for scoring, but a wrong rebound also costs points. \
        Be selective about which rebounds you attempt.
        """

        // Conference Training
        static let conferenceOverview = """
        Train efficient team communication within strict time limits. \
        In real competition, quick and clear team signals can make the difference \
        between winning and losing close matches.
        """

        static let conferenceTimer = """
        Conference time is limited. As you level up in progressive mode, \
        the time decreases: 15 seconds at Level 1, down to 8 seconds at Level 4. \
        This mirrors the pressure of real competition.
        """

        static let conferenceHandSignals = """
        Common hand signals: Thumbs up = I know it confidently. \
        Palm down = I'm uncertain. Point to teammate = They should answer. \
        Establish your team's signal system before competition.
        """

        static let conferenceDifficulty = """
        Progressive difficulty reduces conference time as you improve. \
        This trains you to make quick decisions under pressure, \
        preparing you for high-stakes competition moments.
        """

        // Rebound Training
        static let reboundOverview = """
        Practice capitalizing on opponent mistakes. When they answer incorrectly, \
        decide quickly whether to buzz for the rebound. Good rebound instincts \
        can turn a losing match into a victory.
        """

        static let reboundTiming = """
        You have limited time to decide on a rebound. The faster you buzz, \
        the more confident the system assumes you are. Taking too long \
        may result in another team getting the rebound.
        """

        static let reboundStrategy = """
        Be selective with rebounds. A wrong rebound costs points and momentum. \
        Only buzz if you genuinely know the correct answer. \
        Strategic holds are better than risky rebounds.
        """

        static let reboundProbability = """
        This controls how often the opponent buzzes first, creating rebound opportunities. \
        Lower probability means more rebounds for you to practice. \
        Higher probability simulates stronger opponents who answer more questions.
        """

        // Domain Drill
        static let domainDrillOverview = """
        Focus your practice on a specific knowledge domain. \
        Domain drills help strengthen weak areas and deepen expertise \
        in your strongest subjects.
        """

        static let domainDrillProgressive = """
        Progressive difficulty starts with easier questions and increases \
        as you answer correctly. This builds confidence while challenging you \
        to reach higher levels of mastery.
        """

        static let domainDrillTimePressure = """
        Time pressure mode adds a countdown to each question. \
        This simulates oral round conditions where quick answers \
        give your team an advantage.
        """
    }

    // MARK: - UI Elements

    enum UIElements {
        // Dashboard
        static let quickStart = """
        Jump right into practice! Oral mode for voice-based answers, \
        Written mode for multiple choice questions. Choose based on what you want to practice.
        """

        static let regionSelector = """
        Select your competition region. Rules vary significantly between states: \
        Colorado uses hand signals only, while Minnesota and Washington allow verbal conferring. \
        Scoring and timing also differ.
        """

        static let sessionHistory = """
        Your recent practice sessions with scores and accuracy. \
        Tap a session to see detailed results including domain breakdown \
        and individual question performance.
        """

        static let questionBank = """
        Total questions available for practice, organized by domain. \
        The question bank grows as new content is added. \
        Questions are selected to avoid repetition in close sessions.
        """

        // Settings
        static let opponentDifficulty = """
        Controls how skilled AI opponents are. Beginner: 40% accuracy. \
        Intermediate: 60% accuracy. Advanced: 80% accuracy. Expert: 90%+ accuracy. \
        Start lower and increase as you improve.
        """

        static let progressiveDifficulty = """
        When enabled, difficulty increases as you answer correctly. \
        Conference time decreases, questions get harder, and opponents improve. \
        Great for building skills gradually.
        """

        static let questionCount = """
        How many questions per session. More questions give better statistics \
        but take longer. 10-20 questions is ideal for focused practice.
        """

        static let timePressureMode = """
        Adds countdown timers to simulate competition pressure. \
        Helps build speed and confidence under time constraints.
        """

        // Stats & Metrics
        static let accuracyMeter = """
        Your overall accuracy percentage across all practice. \
        Calculated as correct answers divided by total attempts. \
        Aim for 80%+ before competition.
        """

        static let levelProgress = """
        Your experience level in Knowledge Bowl training. \
        Earn XP by practicing and answering correctly. \
        Higher levels unlock more challenging content.
        """

        static let domainMastery = """
        Mastery percentage for each knowledge domain. \
        Based on accuracy, consistency, and practice volume. \
        Focus on domains below 70% to improve overall performance.
        """

        static let streakCounter = """
        Consecutive correct answers in the current session. \
        Building streaks indicates you're in a good rhythm. \
        Try to beat your personal best streak!
        """

        static let practiceTime = """
        Total time spent practicing Knowledge Bowl. \
        Consistent daily practice of 20-30 minutes is more effective \
        than occasional long sessions.
        """

        static let responseTime = """
        Average time to answer questions. Faster times indicate confidence. \
        In oral rounds, quick answers can intimidate opponents \
        and secure rebounds.
        """
    }

    // MARK: - Strategy Tips

    enum Strategy {
        // Competition Basics
        static let writtenRoundStrategy = """
        Work systematically, skip difficult questions, and always guess since there's no penalty.
        """

        static let oralRoundStrategy = """
        Listen to the entire question unless you're absolutely certain early. \
        Buzzing too early with a wrong answer costs points and morale. \
        Speak clearly and confidently; hesitation can be interpreted as uncertainty.
        """

        static let conferenceStrategy = """
        Develop a signal system with your team beforehand. Practice until signals are automatic.
        """

        static let reboundStrategyTips = """
        Rebounds are golden opportunities but also risky. \
        Only attempt a rebound if you genuinely know the answer. \
        A wrong rebound gives points to opponents and kills momentum.
        """

        static let buzzingStrategy = """
        Buzz when you know the answer, not when you think you might. \
        In team settings, trust your teammates' signals. \
        If multiple teammates signal confidence, the designated answerer should buzz immediately.
        """

        // Advanced Tactics
        static let timeManagement = """
        Written rounds: budget time per question and stick to it. \
        Mark difficult questions to return to. \
        In oral rounds, use full conference time only when truly needed.
        """

        static let teamCommunication = """
        Designate roles and develop hand signals before competition. Debrief after each round.
        """

        static let answerFormulation = """
        Speak in complete, clear answers. Avoid filler words (um, uh). \
        State the most specific correct answer. \
        If asked for a person, give full name when known.
        """

        static let domainStrengths = """
        Know your team's strengths and weaknesses. \
        Assign primary answerers by domain. \
        Practice weak areas but rely on strengths in competition.
        """
    }

    // MARK: - Regional Rules

    enum Regional {
        static let coloradoRules = """
        Colorado: 60 written questions in 15 min, hand signals only during 15-second conference, 4 players per team.
        """

        static let minnesotaRules = """
        Minnesota: 60 written questions in 15 min, verbal conferring allowed during 30-second conference, 4-6 players.
        """

        static let washingtonRules = """
        Washington: 50 written questions in 45 min, verbal conferring allowed during 20-second conference, 3-5 players.
        """

        static let conferenceDifferences = """
        Colorado requires hand signals only; Minnesota and Washington allow verbal discussion during conference.
        """

        static let scoringDifferences = """
        Scoring varies by region. Oral rounds are weighted heavily in all regions (5 pts vs 1-2 pts written).
        """

        static let regionalComparison = """
        Key differences: CO uses signals only (15s), MN allows verbal (30s), WA allows verbal (20s, longer written round).
        """
    }

    // MARK: - watchOS Help

    enum Watch {
        static let quickPracticeOverview = """
        Quick practice sessions for on-the-go learning. \
        Answer 5 or 10 questions with tap-to-reveal answers.
        """

        static let domainDrillOverview = """
        Focus on one knowledge domain at a time. \
        Great for targeted practice during short breaks.
        """

        static let flashCardsOverview = """
        Review questions you've missed or random questions. \
        Tap to flip and reveal the answer.
        """

        static let tapToReveal = """
        Tap the card to reveal the answer. \
        Then mark whether you got it right or wrong.
        """

        static let statsExplanation = """
        Today's stats show your questions answered \
        and accuracy for the current day.
        """
    }

    // MARK: - General Help

    enum General {
        static let gettingStarted = """
        Welcome to Knowledge Bowl training! Start with Oral Practice \
        to build confidence with voice-based answers. Add Written Practice \
        to reinforce question formats, then try Match Simulation for the full experience.
        """

        static let recommendedPath = """
        Start with oral practice, then domain drills, conference training, and match simulation for full prep.
        """

        static let tipsForSuccess = """
        Practice 20-30 min daily, focus on weak domains, use progressive difficulty, and review missed questions.
        """
    }
}
