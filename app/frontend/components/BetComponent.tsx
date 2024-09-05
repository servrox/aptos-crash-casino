import  { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import Swal from 'sweetalert2'; // Import SweetAlert2 for better alerts
import Ufo from "../assets/ufo.png";



export function BetComponent() {
const [multiplier, setMultiplier] = useState<number>(1.0);
const [multiplierHistory, setMultiplierHistory] = useState<number[]>([]); // Track multiplier history
const [betAmount, setBetAmount] = useState<number>(0);
const [isPlaying, setIsPlaying] = useState<boolean>(false);
const [isCrashed, setIsCrashed] = useState<boolean>(false);
const [activeBet, setActiveBet] = useState<boolean>(false);
const [balance, setBalance] = useState<number>(100);
const [countdown, setCountdown] = useState<number>(10);
const [isLoading, setIsLoading] = useState<boolean>(false);
const [countdownCompleted, setCountdownCompleted] = useState<boolean>(false);



  
useEffect(() => {
  let countdownInterval: NodeJS.Timeout;
  if (isCrashed || !isPlaying) {
      setIsLoading(true);
      countdownInterval = setInterval(() => {
          setCountdown((prevCountdown) => {
              if (prevCountdown <= 1) {
                  clearInterval(countdownInterval);
                  setCountdown(10);
                  setIsLoading(false);
                  setIsPlaying(true);
                  setIsCrashed(false); // Reset crash state
                  setMultiplier(1.0);  // Reset multiplier
                  return 10;
              }
              return prevCountdown - 1;
          });
      }, 1000);
  } else if (isPlaying && !isCrashed) {
      const crashAt = Math.random() * 9 + 1; // Random crash between 1 and 10
      const gameInterval = setInterval(() => {
          setMultiplier((prevMultiplier) => prevMultiplier + 0.05);
          if (multiplier >= crashAt) {
              clearInterval(gameInterval);
              setIsCrashed(true);
              setIsPlaying(false);
              setMultiplierHistory((prevHistory) => [...prevHistory, parseFloat(crashAt.toFixed(2))]);
              if (activeBet) {
                  Swal.fire({
                      icon: 'error',
                      title: 'Oops!',
                      text: `Crashed at ${crashAt.toFixed(2)}x! You lost your bet of ${betAmount}.`,
                  });
                  setActiveBet(false);
              }
          }
      }, 100);
      return () => clearInterval(gameInterval);
  }
  return () => clearInterval(countdownInterval);
}, [isPlaying, isCrashed, activeBet, betAmount, multiplier]);


  const handleBet = () => {
    if (betAmount > balance) {
      Swal.fire({
        icon: 'warning',
        title: 'Insufficient Balance',
        text: "You don't have enough balance to place this bet!",
      });
      return;
    }
    setActiveBet(true);
    setBalance(balance - betAmount); // Deduct the bet amount from the balance
    if (!isPlaying) {
      setIsPlaying(true); // Start game after the first bet
    }
  };
  
  const handleCashOut = () => {
    if (activeBet && isPlaying && !isCrashed) {
        const winnings = betAmount * multiplier;
        setBalance((prevBalance) => prevBalance + winnings); // Ensure correct balance update
        Swal.fire({
            icon: 'success',
            title: 'Cashed Out!',
            text: `You cashed out at ${multiplier.toFixed(2)}x! You won ${winnings.toFixed(2)}.`,
        });
        setActiveBet(false);
    }
};


  const handleBetAmountChange = (e:any) => {
    setBetAmount(parseFloat(e.target.value) || 0);
  };


const ufoAnimation = {
    initial: { y: 0, opacity: 1 },
    animate: isCrashed ? { y: -200, opacity: 0 } : { y: [0, -10, 0], transition: { repeat: Infinity, duration: 1 } },
    exit: { y: -200, opacity: 0 },
  };
  

  // Calculate potential win amount
  const potentialWin = activeBet ? betAmount * multiplier : 0;

  return (
    <div className="container mx-auto text-center border border-gray-400 rounded-md">
        {isLoading && (
            <div className="mt-8 text-xl">
                <div>Next Round in: {countdown} seconds</div>
                {/* Add a simple loading spinner */}
                <div className="mt-4 border-t-4 border-blue-500 border-solid w-12 h-12 rounded-full border-t-transparent animate-spin mx-auto"></div>
            </div>
        )}

      <div className="flex flex-col justify-center items-center mt-8">
      <div className="ml-4 text-5xl font-bold">{multiplier.toFixed(2)}x</div>
        <motion.img
          src={Ufo}
          alt="UFO"
          className="w-48 h-48"
          variants={ufoAnimation}
          initial="initial"
          animate="animate"
          exit="exit"
        />
        
      </div>

      <div className="flex justify-center mt-8 space-x-4">
        <button
          className="bg-green-500 text-white px-4 py-2 rounded cursor-pointer"
          onClick={handleBet}
          disabled={isPlaying || activeBet} // Bet only between rounds and once per round
        >
          Place Bet
        </button>
        <button
          className="bg-red-500 text-white px-4 py-2 rounded cursor-pointer"
          onClick={handleCashOut}
          disabled={!activeBet || !isPlaying || isCrashed} // Cash out only if bet is active, playing, and not crashed
        >
          Cash Out
        </button>
      </div>

      <div className="flex justify-center mt-8 space-x-4">
        <input
        type="number"
        value={betAmount}
        onChange={handleBetAmountChange}
        className="border px-4 py-2 rounded text-center"
        min="1"
        placeholder="Bet Amount"
        disabled={isPlaying && countdown >1} // Disable input only if a bet is placed and round is active
        />

{/* <input
  type="number"
  value={betAmount}
  onChange={handleBetAmountChange}
  className="border px-4 py-2 rounded text-center"
  min="1"
  placeholder="Bet Amount"
  disabled={isPlaying && !countdownCompleted} // Allow input if countdown is completed or not active
/> */}

      </div>

      <div className="mt-4 text-xl">Balance: $ {balance.toFixed(2)}</div>

      <div className="mt-2 text-lg">Potential Win: $ {potentialWin.toFixed(2)}</div> {/* Display potential win amount */}
      <div className="flex justify-center mt-8 space-x-2">
        {multiplierHistory.map((value:any, index:any) => (
            <div key={index} className="bg-gray-200 px-2 py-1 rounded">{value}</div>
        ))}
       </div>
      
    </div>
  );
}

