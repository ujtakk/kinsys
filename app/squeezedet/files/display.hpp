#ifndef _DISPLAY_HPP_
#define _DISPLAY_HPP_

#include <deque>
#include <memory>

#include <opencv2/opencv.hpp>

#include "bbox_utils.hpp"

class Display
{
public:
  Display(std::shared_ptr<std::deque<std::pair<Image, Track>>> fifo);
  ~Display();

  void post_frame();

  void sync();

private:
  std::shared_ptr<std::deque<std::pair<Image, Track>>> fifo;
};

#endif
